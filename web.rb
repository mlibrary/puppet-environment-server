require "sinatra"
require_relative "lib/main"

get "/" do
  return "hello yes this is reposync dot container dot jpg"
end

get "/deploy/:ref" do
  sync = Reposync.new(params['ref'])
  sync.deploy!
end

get "/update/:ref" do
  sync = Reposync.new(params['ref'])
  sync.update_libraries!
end
