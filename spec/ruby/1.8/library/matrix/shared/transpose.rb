require 'matrix'

shared :matrix_transpose do |cmd|
  describe "Matrix##{cmd}" do
    it "needs to be reviewed for spec completeness" do
    end
  
    it "transposes rows and columns" do
      Matrix[[1, 2], [3, 4], [5, 6]].transpose.should == Matrix[[1, 3, 5], [2, 4, 6]]
    end
  end
end