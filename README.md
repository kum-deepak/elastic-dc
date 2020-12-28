# DC Data Server - Elastic/Ruby

This is a Proof of Concept data server to run the modified stock example.

## Running it

### Setup

- This has been developed using Elastic Search 7.10.
  Install Elastic Search and update the URL in `src/common.rb`.

- This has been developed using Ruby 2.7,
  however it should work with any new ruby.
  
- To install all required gems, in this folders

```bash
$ bundle install
```

- To create an index in Elastic and index all data needed for the stocks example:

```bash
# It erases previous indices and data
$ bundle exec ruby src/index.rb
```

- To run the server (which is Puma)

```bash
$ bundle exec rackup -p 3030 rackup.ru
```

# Technical details

To come, meanwhile browse the code
