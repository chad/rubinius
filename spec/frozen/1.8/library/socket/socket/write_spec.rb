require File.dirname(__FILE__) + '/../../../spec_helper'
require File.dirname(__FILE__) + '/../fixtures/classes'

describe "TCPServer#write" do
  after(:each) do
    @server.close if @server
    @socket.close if @socket
  end
end
