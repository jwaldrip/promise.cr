class Promise(T)

  def initialize(&block : (T -> Nil) -> _)
    initialize do |resolve, _|
      block.call(resolve)
    end
  end


  def initialize(&block : (T -> Nil), (Exception -> Nil) -> _)
    @resolution = Channel::Buffered(T).new(1)
    @rejection  = Channel::Buffered(Exception).new(1)
    @waiter     = Channel::Buffered(Bool).new(1)
    resolve = ->(value : T) {
      @resolution.send(value)
      @waiter.send(true)
      nil
    }
    reject = ->(err : Exception) {
      @rejection.send(err)
      @waiter.send(true)
      nil
    }
    spawn do
      begin
        block.call(resolve, reject)
      rescue ex : Exception
        reject.call(ex)
      end
    end
  end

  def then(&block : T -> _)
    Promise(T | Nil).new do |resolve, reject|
      resolve.call(block.call(@resolution.receive))
    end
  end

  def catch(&block : Exception -> _)
    Promise(T | Nil).new do |resolve, reject|
      resolve.call(block.call(@rejection.receive))
    end
  end

  def wait
    @waiter.receive
  end

end

promises = [] of Promise(String | Nil)
10.times do
  promises << Promise(String).new do |resolve|
    sleep 3
    resolve.call("done")
  end.then do |result|
    "result: #{result}"
  end.then do |result|
    puts result
    raise "Whoops"
  end.catch do |ex|
    ex.message
  end.then do |message|
    puts message
  end
end

promises.each(&.wait)
