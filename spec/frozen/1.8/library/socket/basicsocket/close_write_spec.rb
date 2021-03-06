require File.dirname(__FILE__) + '/../../../spec_helper'
require File.dirname(__FILE__) + '/../fixtures/classes'
require File.dirname(__FILE__) + '/../fixtures/classes'

describe "Socket::BasicSocket#close_write" do
  before :each do
    @server = TCPServer.new(SocketSpecs.port)    
  end

  after :each do
    @server.close unless @server.closed?
  end

  compliant_on :ruby do
    it "closes the writing end of the socket" do
      @server.close_write
      lambda { @server.write("foo") }.should raise_error(IOError)
    end

    it "works on sockets with closed write ends" do
      @server.close_write
      lambda { @server.close_write }.should_not raise_error(Exception)
      lambda { @server.write("foo") }.should raise_error(IOError)
    end
  end

  not_compliant_on :ruby do
    it "does not work on sockets with closed write ends" do
      @server.close_write
      lambda { @server.close_write }.should raise_error(Exception)
    end

    it "closes the writing end of the socket" do
      @server.close_write
      lambda { @server.write("foo") }.should raise_error(IOError)
    end
  end
end
