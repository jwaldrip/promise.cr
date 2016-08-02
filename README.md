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
require "json"

def read_body(response : HTTP::Client::Response) : String
  response.body
end

request = Promise(HTTP::Client::Response | JSON::Any).new do |resolve|
  resolve.call(HTTP::Client.get "https://httpbin.org/user-agent")
end

puts "do something else...."

request.then do |response|
  JSON.parse(read_body(response as HTTP::Client::Response))
end.catch do |ex|
  puts "caught!"
  puts ex.message
end.then do |json_hash|
  puts json_hash
end.wait
```

## Documentation

You can generate docs using `crystal doc` on your local machine,
or visit: https://jwaldrip.github.com/promise-cr to view the current version's
documentation.

## Contributing

See [CONTRIBUTING](/CONTRIBUTING.md)
