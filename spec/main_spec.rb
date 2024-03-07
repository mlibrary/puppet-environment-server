# frozen_string_literal: true

require 'main'
require 'faker'

class ErrorHandler
end

RSpec.describe Reposync do
  subject(:reposync) { Reposync.new(ref) }
  let(:control_repo_has_branch) { nil }
  let(:deploy_success)          { true }
  let(:remove_success)          { true }
  let(:librarian_success)       { true }

  before(:each) do
    if deploy_success
      allow(PuppetGitUtilities).to receive(:deploy)
    else
      allow(PuppetGitUtilities).to receive(:deploy).and_raise('uh oh')
    end

    if remove_success
      allow(PuppetGitUtilities).to receive(:remove)
    else
      allow(PuppetGitUtilities).to receive(:remove).and_raise('uh oh')
    end

    if librarian_success
      allow(PuppetGitUtilities).to receive(:update_libraries)
    else
      allow(PuppetGitUtilities).to receive(:update_libraries).and_raise('uh oh')
    end

    allow(PuppetGitUtilities).to receive(:write_new_puppetfile)
    allow(PuppetGitUtilities).to receive(:control_repo_has_branch?)
      .and_return(control_repo_has_branch)

    allow(ErrorHandler).to receive(:intercept)
  end

  describe '#deploy!' do
    before(:each) do
      begin
        subject.deploy!
      rescue StandardError
        ErrorHandler.intercept
      end
    end

    context 'when the ref is just a tag' do
      let(:ref) { "refs/tags/v#{Faker::Number.positive}" }

      it 'should do nothing' do
        expect(PuppetGitUtilities).not_to have_received(:deploy)
        expect(PuppetGitUtilities).not_to have_received(:remove)
        expect(PuppetGitUtilities).not_to have_received(:update_libraries)
        expect(PuppetGitUtilities).not_to have_received(:write_new_puppetfile)
        expect(PuppetGitUtilities).not_to have_received(:control_repo_has_branch?)
      end
    end

    context 'when the ref is an environment' do
      let(:ref) { "refs/heads/#{environment}" }
      let(:control_repo_has_branch) { true }

      context 'when the environment is something random' do
        let(:environment) { Faker::Internet.domain_word }

        it 'should deploy that environment' do
          expect(PuppetGitUtilities).to have_received(:deploy).with(environment)
        end

        it 'should not remove anything' do
          expect(PuppetGitUtilities).not_to have_received(:remove)
        end

        it 'should update libraries in that environment' do
          expect(PuppetGitUtilities).to have_received(:update_libraries).with(environment)
        end

        it 'should write a new puppetfile for that environment' do
          expect(PuppetGitUtilities).to have_received(:write_new_puppetfile)
            .with(environment, environment)
        end

        context 'but r10k fails' do
          let(:deploy_success) { false }

          it 'should pass on the error' do
            expect(ErrorHandler).to have_received(:intercept)
          end

          it 'should deploy that environment' do
            expect(PuppetGitUtilities).to have_received(:deploy).with(environment)
          end

          it 'should not remove anything' do
            expect(PuppetGitUtilities).not_to have_received(:remove)
          end

          it 'should not update libraries in that environment' do
            expect(PuppetGitUtilities).not_to have_received(:update_libraries)
          end

          it 'should not write a new puppetfile for that environment' do
            expect(PuppetGitUtilities).not_to have_received(:write_new_puppetfile)
          end
        end

        context 'but librarian-puppet fails' do
          let(:librarian_success) { false }

          it 'should pass on the error' do
            expect(ErrorHandler).to have_received(:intercept)
          end

          it 'should not remove anything' do
            expect(PuppetGitUtilities).not_to have_received(:remove)
          end

          it 'should have written a new puppetfile for that environment' do
            expect(PuppetGitUtilities).to have_received(:write_new_puppetfile)
              .with(environment, environment)
          end
        end

        context "and when that environment doesn't exist" do
          let(:control_repo_has_branch) { false }

          it 'should remove that environment' do
            expect(PuppetGitUtilities).to have_received(:remove).with(environment)
          end

          it 'should not deploy anything' do
            expect(PuppetGitUtilities).not_to have_received(:deploy)
          end

          it 'should not update libraries' do
            expect(PuppetGitUtilities).not_to have_received(:update_libraries)
          end

          it 'should not write a new puppetfile' do
            expect(PuppetGitUtilities).not_to have_received(:write_new_puppetfile)
          end

          context 'but r10k succeeds' do
            let(:remove_success) { false }

            it 'should pass on the error' do
              expect(ErrorHandler).to have_received(:intercept)
            end
          end
        end
      end

      context 'when the environment is production' do
        let(:environment) { 'production' }

        it 'should deploy production' do
          expect(PuppetGitUtilities).to have_received(:deploy).with(environment)
        end

        it 'should not remove anything' do
          expect(PuppetGitUtilities).not_to have_received(:remove)
        end

        it 'should not update libraries in production' do
          expect(PuppetGitUtilities).not_to have_received(:update_libraries)
        end

        it 'should not write a new puppetfile' do
          expect(PuppetGitUtilities).not_to have_received(:write_new_puppetfile)
        end
      end

      context 'when the environment is master' do
        let(:environment) { 'master' }

        it 'should do nothing' do
          expect(PuppetGitUtilities).not_to have_received(:deploy)
          expect(PuppetGitUtilities).not_to have_received(:remove)
          expect(PuppetGitUtilities).not_to have_received(:update_libraries)
          expect(PuppetGitUtilities).not_to have_received(:write_new_puppetfile)
          expect(PuppetGitUtilities).not_to have_received(:control_repo_has_branch?)
        end
      end
    end
  end

  describe '#update_libraries!' do
    before(:each) do
      begin
        subject.update_libraries!
      rescue StandardError
        ErrorHandler.intercept
      end
    end

    context 'when the ref is just a tag' do
      let(:ref) { "refs/tags/v#{Faker::Number.positive}" }

      it 'should do nothing' do
        expect(PuppetGitUtilities).not_to have_received(:deploy)
        expect(PuppetGitUtilities).not_to have_received(:remove)
        expect(PuppetGitUtilities).not_to have_received(:update_libraries)
        expect(PuppetGitUtilities).not_to have_received(:write_new_puppetfile)
        expect(PuppetGitUtilities).not_to have_received(:control_repo_has_branch?)
        expect(ErrorHandler).not_to have_received(:intercept)
      end
    end

    context 'when the ref is a branch' do
      let(:ref) { "refs/heads/#{branch}" }
      let(:control_repo_has_branch) { true }

      context 'when the branch is something random' do
        let(:branch) { Faker::Internet.domain_word }

        it 'should deploy the environment of the same name' do
          expect(PuppetGitUtilities).to have_received(:deploy).with(branch)
        end

        it 'should not remove anything' do
          expect(PuppetGitUtilities).not_to have_received(:remove)
        end

        it 'should update libraries in that environment' do
          expect(PuppetGitUtilities).to have_received(:update_libraries).with(branch)
        end

        it 'should write a new puppetfile for that environment' do
          expect(PuppetGitUtilities).to have_received(:write_new_puppetfile)
            .with(branch, branch)
        end

        context 'but r10k fails' do
          let(:deploy_success) { false }

          it 'should pass on the error' do
            expect(ErrorHandler).to have_received(:intercept)
          end

          it 'should deploy that environment' do
            expect(PuppetGitUtilities).to have_received(:deploy).with(branch)
          end

          it 'should not remove anything' do
            expect(PuppetGitUtilities).not_to have_received(:remove)
          end

          it 'should not update libraries in that environment' do
            expect(PuppetGitUtilities).not_to have_received(:update_libraries)
          end

          it 'should not write a new puppetfile for that environment' do
            expect(PuppetGitUtilities).not_to have_received(:write_new_puppetfile)
          end
        end

        context 'but librarian-puppet fails' do
          let(:librarian_success) { false }

          it 'should pass on the error' do
            expect(ErrorHandler).to have_received(:intercept)
          end

          it 'should not remove anything' do
            expect(PuppetGitUtilities).not_to have_received(:remove)
          end

          it 'should have written a new puppetfile for that environment' do
            expect(PuppetGitUtilities).to have_received(:write_new_puppetfile)
              .with(branch, branch)
          end
        end

        context "and when that environment doesn't exist" do
          let(:control_repo_has_branch) { false }

          it 'should do nothing' do
            expect(PuppetGitUtilities).not_to have_received(:deploy)
            expect(PuppetGitUtilities).not_to have_received(:remove)
            expect(PuppetGitUtilities).not_to have_received(:update_libraries)
            expect(PuppetGitUtilities).not_to have_received(:write_new_puppetfile)
            expect(ErrorHandler).not_to have_received(:intercept)
          end
        end
      end

      context 'when the branch is master' do
        let(:branch) { 'master' }
        let(:control_repo_has_branch) { false }

        it 'should update libraries in production' do
          expect(PuppetGitUtilities).to have_received(:update_libraries).with('production')
        end

        it 'should deploy nothing' do
          expect(PuppetGitUtilities).not_to have_received(:deploy)
        end

        it 'should not remove anything' do
          expect(PuppetGitUtilities).not_to have_received(:remove)
        end

        it 'should not write a new puppetfile' do
          expect(PuppetGitUtilities).not_to have_received(:write_new_puppetfile)
        end
      end
    end
  end
end

RSpec.describe PuppetGitUtilities do
  let(:exit_status)         { double(:exit_status) }
  let(:exit_status_success) { true }
  let(:environment)         { Faker::Internet.domain_word }
  let(:control_repo_path)   { '/usr/local/src/puppet.git' }
  let(:environments_path)   { '/etc/puppetlabs/code/environments' }
  let(:puppetfile) do
    <<~PF
      forge 'https://forge.puppet.com'
      mod 'puppetlabs-stdlib', '4.25.1'
      mod 'example-public', :git => 'https://github.com/example/public'
      mod 'example-private', :git => '/usr/local/src/private.git'
    PF
  end

  before(:each) do
    allow(Open3).to receive(:capture3).and_return(['', '', exit_status])
    allow(exit_status).to receive(:success?).and_return(exit_status_success)

    allow(PuppetGitUtilities).to receive(:read_puppetfile).and_return(puppetfile)
    allow(PuppetGitUtilities).to receive(:main_source).and_return(
      'remote' => control_repo_path,
      'basedir' => environments_path
    )
  end

  describe '.r10k_config' do
    subject { PuppetGitUtilities.r10k_config }

    before(:each) do
      allow(ENV).to receive(:[])
        .with('PUPPET_R10K_CONFIG')
        .and_return(r10k_config)
    end

    context 'with PUPPET_R10K_CONFIG unset' do
      let(:r10k_config) { '' }
      it { is_expected.to be_nil }
    end

    context 'with PUPPET_R10K_CONFIG set to something random' do
      let(:r10k_config) { "/usr/local/#{Faker::Internet.domain_word}.yaml" }
      it { is_expected.to eq Pathname.new(r10k_config) }
    end

    context 'with PUPPET_R10K_CONFIG set to /etc/puppetlabs/r10k/r10k.yaml' do
      let(:r10k_config) { '/etc/puppetlabs/r10k/r10k.yaml' }
      it { is_expected.to be_nil }
    end

    context 'with PUPPET_R10K_CONFIG set to nil' do
      let(:r10k_config) { nil }
      it { is_expected.to be_nil }
    end
  end

  describe '.control_repo' do
    subject { PuppetGitUtilities.control_repo }

    context 'with the remote at /usr/local/src/puppet.git' do
      let(:control_repo_path) { '/usr/local/src/puppet.git' }
      it { is_expected.to eq Pathname.new(control_repo_path) }
    end

    context 'with the remote something random' do
      let(:control_repo_path) { "/usr/local/src/#{Faker::Internet.domain_word}.git" }
      it { is_expected.to eq Pathname.new(control_repo_path) }
    end
  end

  describe '.environments' do
    subject { PuppetGitUtilities.environments }

    context 'with the basedir at /etc/puppetlabs/code/environments' do
      let(:environments_path) { '/etc/puppetlabs/code/environments' }
      it { is_expected.to eq Pathname.new(environments_path) }
    end

    context 'with the basedir at something random' do
      let(:environments_path) { "/opt/#{Faker::Internet.domain_word}" }
      it { is_expected.to eq Pathname.new(environments_path) }
    end
  end

  describe '.deploy' do
    subject { PuppetGitUtilities.deploy(environment) }
    let(:r10k_config) { nil }

    before(:each) do
      allow(PuppetGitUtilities).to receive(:r10k_config).and_return(r10k_config)
    end

    it 'should call r10k' do
      subject
      expect(Open3).to have_received(:capture3)
        .with("r10k deploy environment '#{environment}'")
    end

    context 'when r10k fails' do
      let(:exit_status_success) { false }
      it { expect { subject }.to raise_error(/r10k/) }
      it { expect { subject }.to raise_error(/#{environment}/) }
    end

    context 'with a custom r10k config file' do
      let(:r10k_config) { Pathname.new("/usr/local/#{Faker::Internet.domain_word}.yaml") }

      it 'should call r10k with the explicit config path' do
        subject
        expect(Open3).to have_received(:capture3)
          .with("r10k deploy -c '#{r10k_config}' environment '#{environment}'")
      end
    end
  end

  describe '.remove' do
    subject { PuppetGitUtilities.remove(environment) }
    let(:exit_status_success) { false }
    let(:r10k_config)         { nil }

    before(:each) do
      allow(PuppetGitUtilities).to receive(:r10k_config).and_return(r10k_config)
    end

    it 'should call r10k' do
      subject
      expect(Open3).to have_received(:capture3)
        .with("r10k deploy environment '#{environment}'")
    end

    context 'when r10k succeeds' do
      let(:exit_status_success) { true }
      it { expect { subject }.to raise_error(/r10k/) }
      it { expect { subject }.to raise_error(/#{environment}/) }
    end

    context 'with a custom r10k config file' do
      let(:r10k_config) { Pathname.new("/usr/local/#{Faker::Internet.domain_word}.yaml") }

      it 'should call r10k with the explicit config path' do
        subject
        expect(Open3).to have_received(:capture3)
          .with("r10k deploy -c '#{r10k_config}' environment '#{environment}'")
      end
    end
  end

  describe '.update_libraries' do
    subject { PuppetGitUtilities.update_libraries(environment) }

    it 'should call librarian-puppet in the right environment' do
      subject
      expect(Open3).to have_received(:capture3)
        .with('librarian-puppet update', chdir: "#{environments_path}/#{environment}")
    end

    context 'with an environment with hyphens' do
      let(:environment) { 'this-uses-hyphens' }

      it 'should replace the hyphens with underscores' do
        subject
        expect(Open3).to have_received(:capture3)
          .with('librarian-puppet update', chdir: "#{environments_path}/this_uses_hyphens")
      end
    end

    context 'when librarian-puppet fails' do
      let(:exit_status_success) { false }
      it { expect { subject }.to raise_error(/librarian-puppet/) }
      it { expect { subject }.to raise_error(/#{environment}/) }
    end
  end

  describe '.branch_exists_in_repo?' do
    subject { PuppetGitUtilities.branch_exists_in_repo?(branch, git_repo) }
    let(:git_repo) { '/opt/repo.git' }
    let(:git_ls_remote) do
      git_heads.collect {|branch| "#{Faker::Crypto.sha1}\trefs/heads/#{branch}\n" }.join('')
    end

    before(:each) do
      allow(Open3).to receive(:capture3)
        .with("git ls-remote --heads '#{git_repo}'")
        .and_return([git_ls_remote, '', exit_status])
    end

    context 'when looking for development' do
      let(:branch) { 'development' }

      context 'and only master exists' do
        let(:git_heads) { ['master'] }
        it { is_expected.to eq false }
      end

      context 'and master and development exist' do
        let(:git_heads) { ['development', 'master'] }
        it { is_expected.to eq true }
      end
    end

    context 'when looking for a random branch' do
      let(:branch) { Faker::Internet.domain_word }
      let(:random_heads) do
        heads = Array.new(Faker::Number.between(from: 3, to: 8)) do
          Faker::Internet.domain_word
        end
        heads.push('master').uniq.reject {|i| i == branch }.shuffle
      end

      context "and it's not there" do
        let(:git_heads) { random_heads }
        it { is_expected.to eq false }
      end

      context "and it's not there" do
        let(:git_heads) { random_heads.push(branch).shuffle }
        it { is_expected.to eq true }
      end
    end
  end

  describe '.generate_new_puppetfile' do
    subject { PuppetGitUtilities.generate_new_puppetfile(environment, branch) }
    let(:branch) { environment }

    before(:each) do
      allow(PuppetGitUtilities).to receive(:branch_exists_in_repo?)
        .with(branch, 'https://github.com/example/public')
        .and_return(public_has_branch)
      allow(PuppetGitUtilities).to receive(:branch_exists_in_repo?)
        .with(branch, '/usr/local/src/private.git')
        .and_return(private_has_branch)
    end

    context 'when no git repos have the branch' do
      let(:public_has_branch)  { false }
      let(:private_has_branch) { false }

      it 'returns the puppetfile unchanged' do
        is_expected.to eq(puppetfile)
      end
    end

    context 'when the public repo has the branch' do
      let(:public_has_branch)  { true }
      let(:private_has_branch) { false }

      it { is_expected.to match(/^mod 'example-public',.*, :branch => '#{branch}'$/) }
      it { is_expected.not_to match(/^mod 'example-private',.*, :branch => '#{branch}'$/) }
    end

    context 'when the private repo has the branch' do
      let(:public_has_branch)  { false }
      let(:private_has_branch) { true }

      it { is_expected.not_to match(/^mod 'example-public',.*, :branch => '#{branch}'$/) }
      it { is_expected.to match(/^mod 'example-private',.*, :branch => '#{branch}'$/) }
    end

    context 'when both repos have the branch' do
      let(:public_has_branch)  { true }
      let(:private_has_branch) { true }

      it { is_expected.to match(/^mod 'example-public',.*, :branch => '#{branch}'$/) }
      it { is_expected.to match(/^mod 'example-private',.*, :branch => '#{branch}'$/) }
    end
  end

  describe '.control_repo_has_branch?' do
    subject { PuppetGitUtilities.control_repo_has_branch? environment }

    before(:each) do
      allow(PuppetGitUtilities).to receive(:branch_exists_in_repo?)
        .with(environment, control_repo_path)
        .and_return(branch_exists)
    end

    context 'when the branch does exist' do
      let(:branch_exists) { true }
      it { is_expected.to eq true }
    end

    context 'when the branch does exist' do
      let(:branch_exists) { false }
      it { is_expected.to eq false }
    end
  end
end
