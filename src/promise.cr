class Promise(T)
  class HaltException < Exception ; end

  @catch : Promise(T | Nil) | Nil
  @then : Promise(T | Nil) | Nil

  def initialize(&block : (T -> Nil) -> _)
    initialize do |resolve, _|
      block.call(resolve)
    end
  end

  # Creates a new Promise with procs for how to resolve and how to reject the promise.
  #
  # **NOTE**: Raised exceptions will also trigger a reject.
  def initialize(&block : (T -> Nil), (String | Exception -> Nil) -> _)
    @resolution = Channel::Buffered(T).new(1)
    @rejection  = Channel::Buffered(Exception).new(1)
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

  # Specifies an operation to complete after the previous operation has been resolved.
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

  # Specifies an operation to complete after the previous operation has been resolved.
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

  # Specifies an operation to complete after the previous operation has been
  # rejected.
  #
  # **NOTE:** Using a catch will allow the continuation of the chain after
  # the catch.
  def catch(&block : Exception -> _)
    @catch ||= Promise(T | Nil).new do |resolve|
      begin
        resolve.call(block.call(get_rejection))
      rescue hex : HaltException
        self.then { |result| resolve.call(result) }
      end
    end
  end

  # Will block until the chain before the specified **wait** has finished it's
  # operations, then returns the last value.
  #
  # **NOTE:** This is typically used to prevent the application from terminating
  # before the operations are complete, this may not be required if you have
  # something else handling the process.
  def await
    waiter = Channel::Buffered(T | Nil).new
    self.then do |result|
      waiter.send(result)
      nil
    end
    waiter.receive
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
    nil
  end

  private def reject(message : String)
    reject(Exception.new message)
  end

  private def reject(ex : Exception)
    @resolution.close
    @rejection.send(ex)
    nil
  end

end
