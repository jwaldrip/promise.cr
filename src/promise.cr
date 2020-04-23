class Promise(T)
  class HaltException < Exception ; end

  @catch : Promise(T | Nil) | Nil
  @then : Promise(T | Nil) | Nil
  @resolution_value : T | Nil
  @rejection_value : Exception | Nil

  # The `Promise(T).all(promises : Array(Promise(T | Nil))` method returns a promise that
  # resolves when all of the promises in the iterable argument have resolved, or
  # rejects with the reason of the first passed promise that rejects.
  def self.all(promises : Array(Promise(T | Nil)))
    Promise(Array(T | Nil)).new do |resolve, reject|
      ch = Channel(T | Nil).new(promises.size)
      promises.each do |promise|
        promise.then do |result|
          ch.send result
        end.catch do |ex|
          reject.call(ex)
        end
      end
      resolve.call(promises.map { ch.receive }.to_a)
    end
  end

  # The `Promise(T).execute(&block : -> T)` method returns a Promise object that is resolved
  # by the return value of the block.
  def self.execute(&block : -> T)
    new(&.call(block.call))
  end

  # The `Promise.race(promises : Array(Promise(T | Nil))` method returns a `Promise` that
  # is settled the same way as the first passed promise to settle. It resolves
  # or rejects, whichever happens first.
  def self.race(promises : Array(Promise(T | Nil)))
    Promise(T | Nil).new do |resolve, reject|
      ch = Channel(T | Nil).new(promises.size)
      promises.each do |promise|
        promise.then do |result|
          ch.send result
        end.catch do |ex|
          reject.call(ex)
        end
      end
      resolve.call(ch.receive)
    end
  end

  # The `Promise(T).reject(message : String)` method returns a Promise object that is rejected
  # with the given reason.
  #
  # Rejects with a string message
  def self.reject(message : String)
    reject Exception.new message
  end

  # The `Promise(T).reject(ex : Exception)` method returns a Promise object that is
  # rejected with the given reason.
  #
  # Rejects with an exception.
  def self.reject(ex : Exception)
    execute { raise ex }
  end

  # The `Promise(T).resolve(value : T)` method returns a Promise.then object that is
  # resolved with the given value.
  def self.resolve(value : T)
    execute { value }
  end

  # The `Promise(T).new(&block : (T -> Nil))` method Creates a new Promise with a proc for how to resolve the promise.
  #
  # **NOTE**: Raised exceptions will also trigger a reject.
  def initialize(&block : (T -> Nil) -> _)
    initialize do |resolve, _|
      block.call(resolve)
    end
  end

  # The `Promise(T).new(&block : (T -> Nil), (String | Exception -> Nil) -> _)` method Creates a new Promise with procs for how to resolve and how to reject the promise.
  #
  # **NOTE**: Raised exceptions will also trigger a reject.
  def initialize(&block : (T -> Nil), (String | Exception -> Nil) -> _)
    @resolution = Channel(T).new(1)
    @rejection  = Channel(Exception).new(1)
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

  # The `then(&)` method specifies an operation to complete after the previous operation has been resolved.
  def then(&block : -> _)
    @then ||= Promise(T | Nil).new do |resolve, reject|
      begin
        get_resolution
        value = block.call
        resolve.call value.is_a?(T) ? value : nil
      rescue hex : HaltException
        self.catch { |ex| reject.call(ex) }
      end
    end
  end

  # The `then(&block : T -> _)` method Specifies an operation to complete after the previous operation has been resolved.
  def then(&block : T -> _)
    @then ||= Promise(T | Nil).new do |resolve, reject|
      begin
        value = block.call(get_resolution)
        resolve.call value.is_a?(T) ? value : nil
      rescue hex : HaltException
        self.catch { |ex| reject.call(ex) }
      end
    end
  end

  # The `catch(&block : Exception -> _)` method specifies an operation to complete after the previous operation has been
  # rejected.
  #
  # **NOTE:** Using a catch will allow the continuation of the chain after
  # the catch.
  def catch(&block : Exception -> _)
    @catch ||= Promise(T | Nil).new do |resolve|
      begin
        value = block.call(get_rejection)
        resolve.call value.is_a?(T) ? value : nil
      rescue hex : HaltException
        self.then { |result| resolve.call(result) }
      end
    end
  end

  # The `await` method will block until the chain before the specified **wait** has finished it's
  # operations, then returns the last value.
  #
  # **NOTE:** This is typically used to prevent the application from terminating
  # before the operations are complete, this may not be required if you have
  # something else handling the process.
  def await
    waiter = Channel(T | Nil).new
    self.then do |result|
      waiter.send(result)
      nil
    end.catch do |ex|
      waiter.send nil
    end
    waiter.receive
  end

  # The `state` method will return the current state of the `Promise`.
  def state
    case
    when resolved?
      :resolved
    when rejected?
      :rejected
    when pending?
      :pending
    end
  end

  # The `pending?` method will return true if the `Promise` is pending.
  def pending?
    !resolved? && !rejected?
  end

  # The `rejected?` method will return true if the `Promise` is rejected.
  def rejected?
    !@rejection_value.nil?
  end

  # The `resolved?` method will return true if the `Promise` is resolved.
  def resolved?
    !@resolution_value.nil?
  end

  private def get_resolution
    @resolution_value ||= begin
      @resolution.receive
    rescue ex : Channel::ClosedError
      raise HaltException.new(message: ex.message, cause: ex)
    end
  end

  private def get_rejection
    @rejection_value ||= begin
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
