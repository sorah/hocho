# Hocho: an itamae wrapper

Hocho is a wrapper of the provisioning tool [itamae](https://github.com/itamae-kitchen/itamae).

## Features

- `itamae ssh` support
- remote `itamae local` support on rsync+bundler
- Simple pluggable host inventory, discovery

## vs. other softwares

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'hocho'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hocho

## Setup

``` yaml
# hocho.yml
inventory_providers:
  file:
    path: './hosts'
```

```
# ./hosts/test.yml
test.example.org:
  # ssh_options:
  #   user: ...
  properties:
    run_list:
      - roles/app/default.rb
```

```
$ hocho list
$ hocho show test.example.org
$ hocho apply test.example.org
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/hocho.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

