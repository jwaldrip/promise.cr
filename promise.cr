class Promise(T)
  class HaltException < Exception ; end

  def initialize(&block : (T -> Nil) -> _)
    initialize do |resolve, _|
      block.call(resolve)
    end
  end

  def initialize(&block : (T -> Nil), (String -> Nil) -> _)
    @resolution = Channel::Buffered(T).new(1)
    @rejection  = Channel::Buffered(Exception).new(1)
    @waiter     = Channel::Buffered(Bool).new(1)
    resolve = ->(value : T) {
      @rejection.close
      @resolution.send(value)
      @waiter.send(true)
      nil
    }
    reject = ->(err : Exception) {
      @resolution.close
      @rejection.send(err)
      @waiter.send(true)
      nil
    }
    spawn do
      begin
        block.call(resolve, ->(message : String){ reject.call(Exception.new(message)) })
      rescue ex : Exception
        reject.call(ex)
      end
    end
  end

  def then(&block)
    Promise(T | Nil).new do |resolve|
      @resolution.receive
      resolve.call(block.call)
    end
  end

  def then(&block : T -> _)
    Promise(T | Nil).new do |resolve|
      begin
        resolve.call(block.call(get_resolution))
      rescue ex : HaltException
        nil
      end
    end
  end

  def catch(&block : Exception -> _)
    Promise(T | Nil).new do |resolve|
      begin
        resolve.call(block.call(get_rejection))
      rescue ex : HaltException
        self.then { |result| resolve.call(result) }
      end
    end
  end

  private def get_resolution
    begin
      @resolution.receive
    rescue ex : Channel::ClosedError
      raise HaltException.new(message: ex.message, cause: ex)
    end
  end

  private def get_rejection
    begin
      @rejection.receive
    rescue ex : Channel::ClosedError
      raise HaltException.new(message: ex.message, cause: ex)
    end
  end

  def wait
    @waiter.receive
  end

end
