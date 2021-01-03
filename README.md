# DC Data Server - Elastic/Ruby

This is a Proof of Concept data server to run the modified stock example.

## Quick start

- This has been developed using Elastic Search 7.10. Install Elastic Search and update the URL
  in [src/common.rb](src/common.rb).
- This has been developed using Ruby 2.7, however it should work with any new ruby.
- To install all required gems, in this folders

```bash
$ bundle install
```

- To create an index in Elastic and index all data needed for the stocks example:

```bash
# To create the index
# caution: it deletes previous index
$ bundle exec ruby src/create_index.rb

# Import data
$ bundle exec ruby src/data_import.rb
```

- To run the (Puma) server

```bash
$ bundle exec rackup -p 3030 rackup.ru
```

## Making it work for you

### Index Structure

You will need to define fields in the index. Though not necessary, it is recommended that you explicitly define types
for all fields. While any indices has no restriction on filed types, only simple types - numeric, date, and keyword -
are supported as dimensions. Crossfilter allows computed values as dimensions - for those create a field and compute it
while indexing.

The file [src/create_index.rb](src/create_index.rb) may be used as a sample. If you are new to Elastic, you may consider
an Index as a Table in a database.

See the following to learn more:

- https://www.elastic.co/guide/en/elasticsearch/reference/current/indices-create-index.html
- https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping.html
- https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping-types.html

Change the name of the index as per your preference. You will need to use the same index name
in [src/conf.rb](src/conf.rb).

**Supported data types:**

| Elastic Type | Use as Dimension | Simple Filters | Range FIlters |
| :----------- | :--------------: | :------------: | :-----------: |
|  Keyword     | Yes              | Yes            | No            |
|  Integer     | Yes              | Yes            | Yes           |
|  Decimal     | Yes              | No             | Yes           |
|  Date        | Yes              | Yes            | Yes           |

To create the index:

```bash
# caution: it deletes previous index
$ bundle exec ruby src/create_index.rb
```

### Import data

Usually your application will update data in the Elastic index.

The sample [src/data_import.rb](src/data_import.rb) shows how to import data from csv files. It
uses [CSV](https://ruby-doc.org/stdlib-2.6.1/libdoc/csv/rdoc/CSV.html) from Ruby standard library. There is a
similar [JSON](https://ruby-doc.org/stdlib-2.6.1/libdoc/json/rdoc/JSON.html)
library.

Before importing data each field will need to be converted to their specific types as defined the index mapping.
Pre-computing synthetic fields - especially the ones that are going to be used as dimensions - is going to help.

The sample uses Elastic bulk APIs to index. See:
[https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-bulk.html](https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-bulk.html)
.

```bash
# Import data
$ bundle exec ruby src/data_import.rb
```

### Dimensions and Groups

See file [src/conf.rb](src/conf.rb).

Any of the supported filed types can be used as dimension.
By default number of matching rows (documents in Elastic terminology) will the value,
which is same as CrossFilter default Group.

Elastic has quite rich support for creating aggregations.
This sample uses Term aggregation combined with Pipeline aggregations:

- [https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-bucket-terms-aggregation.html](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-bucket-terms-aggregation.html)
- [https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-pipeline.html](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-pipeline.html)

[src/conf.rb](src/conf.rb) shows a variety of aggregation types.

The example also shows how to associate multiple groups to one dimension.

## Production use

Though it has missing features, the implementation is high quality.

- The indexing uses bul APIs.
- At the time of query - all queries are sent is one go using bulk API.
- If a dimension is used by multiple groups, these are combined as a single set of aggregation.
- The code is multi thread safe. Entire shared data is immutable.
- This code is written in way to easily be adapted to other Ruby based app servers.

## Missing features

- Filter types other than simple and range. *In roadmap*
- Ability to get rows (for data table, data grid). *In roadmap*
- Composite keys are not supported for dimension.
