#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'
require 'pathname'
require 'yaml'

DEFAULT_R10K_CONFIG = Pathname.new('/etc/puppetlabs/r10k/r10k.yaml')

# tests are documentation, rubocop
class Reposync
  def initialize(ref)
    @branch = nil

    if ref =~ %r{^refs/heads/(.*)$}
      @branch = Regexp.last_match(1)
    end
  end

  def deploy!
    if ref_is_a_branch?
      raise 'you cannot have a master environment' if branch == 'master'

      if control_repo_has_branch?
        deploy_environment
        update_libraries unless branch == 'production'

      else
        remove_environment
      end
    end
  end

  def update_libraries!
    if ref_is_a_branch? && control_repo_has_branch?
      deploy_environment unless branch == 'master'
      update_libraries
    end
  end

  private

  attr_reader :branch

  def ref_is_a_branch?
    !branch.nil?
  end

  def control_repo_has_branch?
    branch == 'master' || PuppetGitUtilities.control_repo_has_branch?(branch)
  end

  def deploy_environment
    PuppetGitUtilities.deploy branch
  end

  def remove_environment
    PuppetGitUtilities.remove branch
  end

  def update_libraries
    if %w[master production].include? branch
      PuppetGitUtilities.update_libraries 'production'
    else
      PuppetGitUtilities.write_new_puppetfile(branch, branch)
      PuppetGitUtilities.update_libraries branch
    end
  end
end

# tests are documentation, rubocop
class PuppetGitUtilities
  def self.deploy(environment)
    _, _, status = Open3.capture3(PuppetGitUtilities.get_r10k_command(environment))
    raise "r10k failed to deploy environment #{environment}" unless status.success?
  end

  def self.remove(environment)
    _, _, status = Open3.capture3(PuppetGitUtilities.get_r10k_command(environment))
    raise "r10k didn't remove environment #{environment}" if status.success?
  end

  def self.get_r10k_command(environment)
    if PuppetGitUtilities.r10k_config.nil?
      "r10k deploy environment '#{environment}'"
    else
      "r10k deploy -c '#{PuppetGitUtilities.r10k_config}' environment '#{environment}'"
    end
  end

  def self.update_libraries(environment)
    _, _, status = Open3.capture3('librarian-puppet update',
      chdir: PuppetGitUtilities.environment_path(environment).to_s)
    raise "librarian-puppet failed to update #{environment}" unless status.success?
  end

  def self.write_new_puppetfile(environment, branch)
    PuppetGitUtilities.puppetfile(environment).write(
      PuppetGitUtilities.generate_new_puppetfile(environment, branch)
    )
  end

  def self.generate_new_puppetfile(environment, branch)
    PuppetGitUtilities.read_puppetfile(environment).gsub(/:git *=> *'([^']*)' *$/) do |match|
      git_repo = Regexp.last_match(1)
      if PuppetGitUtilities.branch_exists_in_repo?(branch, git_repo)
        "#{match}, :branch => '#{branch}'"
      else
        match
      end
    end
  end

  def self.read_puppetfile(environment)
    PuppetGitUtilities.puppetfile(environment).read
  end

  def self.puppetfile(environment)
    PuppetGitUtilities.environment_path(environment) / 'Puppetfile'
  end

  def self.environment_path(environment)
    PuppetGitUtilities.environments / environment.tr('-', '_')
  end

  def self.control_repo_has_branch?(branch)
    PuppetGitUtilities.branch_exists_in_repo?(branch, PuppetGitUtilities.control_repo.to_s)
  end

  def self.branch_exists_in_repo?(branch, git_repo)
    ls_remote, = Open3.capture3("git ls-remote --heads '#{git_repo}'")
    %r{\srefs/heads/#{branch}$}.match? ls_remote
  end

  def self.control_repo
    Pathname.new(PuppetGitUtilities.main_source['remote'])
  end

  def self.environments
    Pathname.new(PuppetGitUtilities.main_source['basedir'])
  end

  def self.main_source # rubocop:disable Metrics/MethodLength
    data = YAML.safe_load(PuppetGitUtilities.r10k_config_path.read)
    sources = if data.key? :sources
      data[:sources]
    else
      data['sources']
    end

    sources.each_value do |values|
      return values unless values.key? 'prefix'
      return values unless values['prefix']
    end

    raise "couldn't parse r10k config #{PuppetGitUtilities.r10k_config_path}"
  end

  def self.r10k_config_path
    if PuppetGitUtilities.r10k_config.nil?
      DEFAULT_R10K_CONFIG
    else
      PuppetGitUtilities.r10k_config
    end
  end

  def self.r10k_config
    path = ENV['PUPPET_R10K_CONFIG']
    Pathname.new(path) unless [nil, '', DEFAULT_R10K_CONFIG.to_s].include? path
  end
end

ACTIONS = %w[deploy update].freeze
USAGE = "[-h] (#{ACTIONS.join('|')}) REF"

def error_out(message)
  warn "usage: #{$PROGRAM_NAME} #{USAGE}"
  warn "#{$PROGRAM_NAME}: error: #{message}"
  exit 1
end

if $PROGRAM_NAME == __FILE__
  require 'getoptlong'
  options = GetoptLong.new(
    ['--help', '-h', GetoptLong::NO_ARGUMENT]
  )

  options.each do |option, _argument|
    case option
    when '--help'
      puts <<~HELP
        usage: #{$PROGRAM_NAME} #{USAGE}

        Sync puppet's environments with any modules under our control. When the
        control repository itself has been updated, this should be run with
        `deploy`; when one of our modules has been updated, this should be run
        with `update`.

        If this isn't working, it's probably because you haven't set
        PUPPET_R10K_CONFIG in your environment, and your r10k config is located
        somewhere other than #{DEFAULT_R10K_CONFIG}

        positional arguments:
         ACTION      whether we're to deploy an environment or update modules
         REF         the git ref that's just been pushed

        optional arguments:
         -h, --help  show this help message and exit
      HELP
      exit 0
    end
  end

  error_out 'expected exactly 2 arguments' unless ARGV.size == 2

  action, ref = ARGV
  error_out "unknown action: #{action}" unless ACTIONS.include? action

  sync = Reposync.new(ref)

  case action
  when 'deploy'
    sync.deploy!

  when 'update'
    sync.update_libraries!
  end
end
