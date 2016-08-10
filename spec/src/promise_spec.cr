require "../spec_helper"

describe Promise do
  describe ".reject(T)" do
    it "should reject with a value" do
      value = nil
      exception = nil
      Promise(String).reject("reason").then do |v|
        value = v
      end.catch do |ex|
        exception = ex
      end.await
      value.should be_nil
      exception.should be_a Exception
      (exception as Exception).message.should eq "reason"
    end
  end

  describe ".reject(Exception)" do
    it "should reject with a value" do
      value = nil
      exception = nil
      Promise(String).reject(Exception.new "reason").then do |v|
        value = v
      end.catch do |ex|
        exception = ex
      end.await
      value.should be_nil
      exception.should be_a Exception
      (exception as Exception).message.should eq "reason"
    end
  end

  describe ".resolve(T)" do
    it "should reject with a value" do
      value = nil
      exception = nil
      Promise(String).resolve("value").then do |v|
        value = v
      end.catch do |ex|
        exception = ex
      end.await
      exception.should be_nil
      (value as String).should eq "value"
    end
  end

  describe ".all(Array(T | Nil))" do
    context "when all pass" do
      it "should return an array of values" do
        exception = nil
        values = [] of String
        promises = 10.times.map do |i|
          Promise(String | Int32).resolve(i).then do |i|
            sleep (i as Int32) / 10
            "value #{i}"
          end
        end.to_a
        Promise(String | Int32).all(promises).then do |v|
          values = v
        end.catch do |ex|
          exception = ex
        end.await
        exception.should be_nil
        values.map(&.to_s).sort.each_with_index do |v, i|
          v.should eq "value #{i}"
        end
      end
    end

    context "when one fails" do
      it "should catch" do
        exception = nil
        values = [] of String
        promises = 10.times.map do |i|
          Promise(String | Int32).resolve(i).then do |i|
            sleep (i as Int32) / 10
            raise "Oops" if (i as Int32) > 4
            "value #{i}"
          end
        end.to_a
        Promise(String | Int32).all(promises).then do |v|
          values = v
        end.catch do |ex|
          exception = ex
        end.await
        exception.should be_a Exception
        values.size.should eq 0
        (exception as Exception).message.should eq "Oops"
      end
    end
  end

  describe ".race(Array(T | Nil))" do
    context "when one passes first" do
      it "should return an array of values" do
        exception = nil
        first_value = nil
        promises = 10.times.map do |i|
          Promise(String | Int32).resolve(i).then do |i|
            sleep (i as Int32) / 10
            raise "Oops" if (i as Int32) > 4
            "value #{i}"
          end
        end.to_a
        Promise(String | Int32).race(promises).then do |fv|
          first_value = fv
        end.catch do |ex|
          exception = ex
        end.await
        exception.should be_nil
        first_value.should eq "value 0"
      end
    end

    context "when one fails first" do
      it "should catch" do
        exception = nil
        first_value = nil
        promises = 10.times.map do |i|
          Promise(String | Int32).resolve(i).then do |i|
            sleep (i as Int32) / 10
            raise "Oops" if (i as Int32) < 4
            "value #{i}"
          end
        end.to_a
        Promise(String | Int32).race(promises).then do |fv|
          first_value = fv
        end.catch do |ex|
          exception = ex
        end.await
        exception.should be_a Exception
        first_value.should be_nil
        (exception as Exception).message.should eq "Oops"
      end
    end
  end

  describe ".execute(&block)" do
    it "should resolve with the return value of the block" do
      value = nil
      Promise(String).execute { "Hello" }.then do |v|
        value = v
      end.await
      value.should eq "Hello"
    end

    context "when raised" do
      it "should reject" do
        exception = nil
        Promise(String).execute { raise "oops" }.catch do |ex|
          exception = ex
        end.await
        exception.should be_a Exception
        (exception as Exception).message.should eq "oops"
      end
    end
  end

  describe ".new(&block : (T -> Nil) -> _)" do
    it "should create a promise and complete its task" do
      value = nil
      Promise(String).new do |resolve|
        value = "hello"
        resolve.call(value as String)
      end.await
      value.should eq "hello"
    end

    context "when raised" do
      it "should reject" do
        exception = nil
        Promise(String).new do |resolve|
          raise "Oops"
        end.catch do |ex|
          exception = ex
        end.await
        exception.should be_a Exception
        (exception as Exception).message.should eq "Oops"
      end
    end
  end

  describe "#state" do
    context "when pending" do
      it "should be pending" do
        promise = Promise(String).new do |resolve|
        end
        promise.state.should eq :pending
      end
    end

    context "when resolved" do
      it "should be pending" do
        promise = Promise(String).resolve("done").tap(&.await)
        promise.state.should eq :resolved
      end
    end

    context "when rejected" do
      it "should be rejected" do
        promise = Promise(String).reject("error").tap(&.await)
        promise.state.should eq :rejected
      end
    end
  end

  describe "#pending?" do
    context "when pending" do
      it "should be true" do
        promise = Promise(String).new do |resolve|
        end
        promise.pending?.should eq true
      end
    end

    context "when resolved" do
      it "should be false" do
        promise = Promise(String).resolve("done").tap(&.await)
        promise.pending?.should eq false
      end
    end

    context "when rejected" do
      it "should be false" do
        promise = Promise(String).reject("error").tap(&.await)
        promise.pending?.should eq false
      end
    end
  end

  describe "#resolved?" do
    context "when pending" do
      it "should be false" do
        promise = Promise(String).new do |resolve|
        end
        promise.resolved?.should eq false
      end
    end

    context "when resolved" do
      it "should be true" do
        promise = Promise(String).resolve("done").tap(&.await)
        promise.resolved?.should eq true
      end
    end

    context "when rejected" do
      it "should be false" do
        promise = Promise(String).reject("error").tap(&.await)
        promise.resolved?.should eq false
      end
    end
  end

  describe "#rejected?" do
    context "when pending" do
      it "should be false" do
        promise = Promise(String).new do |resolve|
        end
        promise.rejected?.should eq false
      end
    end

    context "when resolved" do
      it "should be false" do
        promise = Promise(String).resolve("done").tap(&.await)
        promise.rejected?.should eq false
      end
    end

    context "when rejected" do
      it "should be true" do
        promise = Promise(String).reject("error").tap(&.await)
        promise.rejected?.should eq true
      end
    end
  end
end
