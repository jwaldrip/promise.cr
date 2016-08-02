# Crystal Promise
A Promise Implementation in Crystal.

## Installation

Add `promise` to the shard.yml file as a dependency.

```yml
# shard.yml
dependencies:
  promise:
    github: jwaldrip/promise-cr
    tag: 1.0.0
```

## Usage

```crystal
require "promise"
require "http/client"

request = Promise.new do |resolve|
  HTTP::Client.get "https://httpbin.org/user-agent" do |response|
    raise "request error" unless response.status_code < 400
    resolve.call(response)
  end
end

puts "do something else..."

request.then do |response|
  puts JSON.parse(respone.json)
end.catch do |ex|
  puts "Error: #{ex.message}"
end
```
