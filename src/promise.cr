class Promise(T)
  class HaltException < Exception ; end

  @catch : Promise(T | Nil) | Nil
  @then : Promise(T | Nil) | Nil

  def initialize(&block : (T -> Nil) -> _)
    initialize do |resolve, _|
      block.call(resolve)
    end
  end

  # Creates a new Promise with a resolve and a reject
  def initialize(&block : (T -> Nil), (String | Exception -> Nil) -> _)
    @resolution = Channel::Buffered(T).new(1)
    @rejection  = Channel::Buffered(Exception).new(1)
    @waiter     = Channel::Buffered(Bool).new(1)
    _resolve = ->(value : T){ resolve(value) }
    _reject = ->(ex : String | Exception){ reject(ex) }
    spawn do
      begin
        block.call(_resolve, _reject)
      rescue ex : Exception
        _reject.call(ex)
      end
    end
  end

  def then(&block)
    @then ||= Promise(T | Nil).new do |resolve, reject|
      begin
        get_resolution
        resolve.call(block.call)
      rescue hex : HaltException
        self.catch { |ex| reject.call(ex) }
      end
    end
  end

  def then(&block : T -> _)
    @then ||= Promise(T | Nil).new do |resolve, reject|
      begin
        self.catch { |ex| reject.call(ex) }
        resolve.call(block.call(get_resolution))
      rescue hex : HaltException
        self.catch { |ex| reject.call(ex) }
      end
    end
  end

  def catch(&block : Exception -> _)
    @catch ||= Promise(T | Nil).new do |resolve|
      begin
        resolve.call(block.call(get_rejection))
      rescue hex : HaltException
        self.then { |result| resolve.call(result) }
      end
    end
  end

  def wait
    @waiter.receive
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

  private def resolve(value : T)
    @rejection.close
    @resolution.send(value)
    @waiter.send(true)
    nil
  end

  private def reject(message : String)
    reject(Exception.new message)
  end

  private def reject(ex : Exception)
    @resolution.close
    @rejection.send(ex)
    @waiter.send(true)
    nil
  end

end
