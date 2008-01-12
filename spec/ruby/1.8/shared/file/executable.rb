shared :file_executable do |cmd, klass|
  describe "#{klass}.#{cmd}" do 
    before :each do
      @file1 = 'temp1.txt'
      @file2 = 'temp2.txt'

      File.open(@file1, "w"){} # touch
      File.open(@file2, "w"){} # touch

      File.chmod(0755, @file1)
    end

    after :each do
      File.delete(@file1) if File.exist?(@file1)    
      File.delete(@file2) if File.exist?(@file2)

      @file1 =  nil
      @file2 = nil
    end

    it "returns true if named file is readable by the effective user id of the process, otherwise false" do
      klass.send(cmd, 'fake_file').should == false
      klass.send(cmd, '/etc/passwd').should == false
      klass.send(cmd, @file1).should == true
      klass.send(cmd, @file2).should == false
    end

    platform_is_not :mswin do
      it "return true if the argument its an executable file" do
        klass.send(cmd, @file1).should == true
        klass.send(cmd, @file2).should == false
        klass.send(cmd, 'a_fake_file').should == false
      end
    end

    it "raises an ArgumentError if not passed one argument" do
      lambda { klass.send(cmd) }.should raise_error(ArgumentError)
    end

    it "raises a TypeError if not passed a String type" do
      lambda { klass.send(cmd, 1)     }.should raise_error(TypeError)
      lambda { klass.send(cmd, nil)   }.should raise_error(TypeError)
      lambda { klass.send(cmd, false) }.should raise_error(TypeError)
    end
  end
end