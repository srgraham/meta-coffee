
#{runtime: {subclass, Stack, OMeta}} = require '../../bin/metacoffee'
{runtime: {subclass, Stack, OMeta}} = require '../../lib/metacoffee/index'




ometa BaseOmeta
  default_delimiter      = spaces ',' spaces
  repeat1n :r            = apply(r):val1 (default_delimiter apply(r))*:valn -> [val1].concat valn
  repeat0n :r            = repeat1n(r)
                         | empty
  repeat :r :amount      = {count = 0} (&{count < amount} apply(r))*:out -> out
  repeatBetween :r :a :b = {count = 0} (&{count < b} apply(r))*:out &{count > a} -> out
  func_call              = '(' repeat0n('param'):params ')' -> ['FuncCall', params]
  param                  = (digit+):out -> out.join ''
                         | quoted_string
  quoted_string          = "'" (!"'" char)*:str "'" -> str.join('')
                         | '"' (!'"' char)*:str '"' -> str.join('')
  backtick               = '\xff' # todo: fix this


#ometa SQLCreateTableParser extends BaseOmeta
#  param                  = digit
#  func_call = "thing(" repeat1n('param'):params ")"-> params
#  quoted_string
#
# func_call2  = "thing(" substitute('param') ",5,6)"


#str = 'thing(4,5,3)'
#console.log SQLCreateTableParser.matchAll str, 'func_call'

blankObj = ()->
  return {}

ometa SQLCreateTableParser extends BaseOmeta
  sql_safe_name = (letter | digit | '_')+:out -> out.join ''
  sql_name = sql_safe_name:out -> out
             | backtick ( !backtick anything )+:out backtick -> out.join ''

  create_table = "CREATE" spaces {@table_flags = blankObj()} is_temporary? spaces "TABLE" spaces sql_name:table_name
                 if_not_exists?
                 spaces "(" spaces repeat1n('create_def'):defs ")"
                 engine? default_charset? comment?
                 -> ['CreateTable', table_name, defs, @table_flags ]

  create_def = sql_name:col_name column_definition:col_def -> ['CreateDef', col_name, col_def]
             | ( "INDEX" | "KEY" ) spaces sql_name:index_name spaces "(" spaces repeat1n('sql_name'):index_columns spaces ")" -> ['CreateIndex', index_name, index_columns]
             | "CONSTRAINT" spaces sql_name:foreign_key_name spaces "FOREIGN KEY" spaces "(" spaces repeat1n('sql_name'):index_columns spaces ")"
               "REFERENCES" spaces sql_name:foreign_table spaces "(" spaces repeat1n('sql_name'):foreign_columns spaces ")" -> ['CreateForeign', foreign_key_name, index_columns, foreign_table, foreign_columns]

  column_definition = data_type:data_type
                      (
                        spaces (
                          not_null
                        | null
                        | default_value
                        | auto_increment
                        | unique_key
                        | primary_key
                        | comment
                        )
                      )*
                      -> ['ColDef', data_type, @def_flags]

  data_type = {@def_flags = blankObj()}
            (
                ( "BIT":type func_call?:params )
              | ( "TINYINT" | "SMALLINT" | "MEDIUMINT" | "INT" | "INTEGER" | "BIGINT" ):type func_call?:params unsigned? zerofill?
              | ( "VARCHAR" | "CHAR" ):type func_call?:params binary?
              | ( "TINYTEXT" | "TEXT" | "MEDIUMTEXT" | "LONGTEXT" ) ''?:params binary?
            ) -> ['DataType', type, params, @def_flags]

  not_null       = spaces "NOT" spaces "NULL" spaces {@def_flags.not_null = true} -> true
  null           = spaces "NULL" spaces {@def_flags.null = true} -> true
  auto_increment = spaces "AUTO_INCREMENT" spaces {@def_flags.auto_increment = true} -> true
  unsigned       = spaces "UNSIGNED" spaces {@def_flags.unsigned = true} -> true
  zerofill       = spaces "ZEROFILL" spaces {@def_flags.zerofill = true} -> true
  binary         = spaces "BINARY" spaces {@def_flags.binary = true} -> true

  unique_key     = spaces "UNIQUE" spaces ("KEY" spaces)? {@def_flags.unique_key = true} -> true
  primary_key    = spaces "PRIMARY" spaces ("KEY" spaces)? {@def_flags.primary_key = true} -> true

  default_value  = spaces "DEFAULT" spaces ("NULL" | quoted_string):default_value {@def_flags.default_value = default_value} -> default_value
  comment        = spaces "COMMENT" spaces quoted_string:comment {@def_flags.comment = comment} -> comment

  if_not_exists  = spaces "IF" spaces "NOT" spaces "EXISTS" {@table_flags.if_not_exists = true} -> true
  is_temporary   = spaces "TEMPORARY" {@table_flags.temporary = true} -> true



str = '''
CREATE TABLE project
(
    id INT(11) PRIMARY KEY NOT NULL AUTO_INCREMENT,
    name VARCHAR(255),
    description TEXT COMMENT 'asdfasdf',
    technical_description TEXT,
    type INT(11),
    is_archived TINYINT(1) DEFAULT '0' NOT NULL,
    technology_bucket INT(11),
    created_at INT(11),
    created_by INT(11),
    updated_at INT(11),
    updated_by INT(11),
    pid INT(11),
    theater_id INT(11),
    project_manager INT(11),
    manager INT(11),
    theater_service_delivery_manager INT(11),
    client_theater_id INT(11),
    account_team_primary_poc INT(11),
    account_team_se INT(11),
    business_value INT(11),
    hours_booked INT(11),
    service_type_id INT(11),
    sku_id INT(11),
    is_dsa TINYINT(1),
    practice_team_id INT(11),
    location_id INT(11),
    is_hidden TINYINT(1),
    is_cap_case TINYINT(1),
    wiki_url VARCHAR(1024),
    other_url VARCHAR(1024),
    tims_id VARCHAR(255),

'''
console.log SQLCreateTableParser.matchAll str, 'create_table'

#str = '`'
#console.log SQLCreateTableParser.matchAll str, 'backtick'