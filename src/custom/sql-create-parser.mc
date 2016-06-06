
#{runtime: {subclass, Stack, OMeta}} = require '../../bin/metacoffee'
{runtime: {subclass, Stack, OMeta}} = require '../../lib/metacoffee/index'

exactlyCI = (wanted) ->
  next = @_apply("anything")

  #console.log 111, wanted, next, wanted.toLowerCase(), next.toLowerCase(), (wanted.toLowerCase() == next.toLowerCase())

  if wanted.toLowerCase() == next.toLowerCase()
    return wanted
  throw @fail

seqCI = (xs)->
  for x in xs
    exactlyCI.apply @, [x]
  return xs

ometa BaseOmeta
  lineComment            = fromTo('--', '\n'):comment { @comments ?= []; @comments.push comment } -> ['Comment', comment]
  blockComment           = fromTo('/*', '*/'):comment { @comments ?= []; @comments.push comment } -> ['Comment', comment]
  space = ^space
        | lineComment
        | blockComment
  spaces = space*

  handleComments = { @_comments = @comments ; @comments = [] } -> @_comments

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
  testing                = i('ppp')
  keyword :xs            = spaces i(xs)
  i :xs                  = { seqCI.apply(this, [xs]) }

  # SQL case insensitive keywords
  INDEX = keyword('INDEX')
  CREATE = keyword('CREATE')
  TABLE = keyword('TABLE')
  KEY = keyword('KEY')
  FOREIGN = keyword('FOREIGN')
  CONSTRAINT = keyword('CONSTRAINT')
  REFERENCES = keyword('REFERENCES')
  BIT = keyword('BIT')
  TINYINT = keyword('TINYINT')
  SMALLINT = keyword('SMALLINT')
  MEDIUMINT = keyword('MEDIUMINT')
  INT = keyword('INT')
  INTEGER = keyword('INTEGER')
  BIGINT = keyword('BIGINT')
  VARCHAR = keyword('VARCHAR')
  CHAR = keyword('CHAR')
  TINYTEXT = keyword('TINYTEXT')
  TEXT = keyword('TEXT')
  MEDIUMTEXT = keyword('MEDIUMTEXT')
  LONGTEXT = keyword('LONGTEXT')
  NOT = keyword('NOT')
  NULL = keyword('NULL')
  UNSIGNED = keyword('UNSIGNED')
  ZEROFILL = keyword('ZEROFILL')
  BINARY = keyword('BINARY')
  UNIQUE = keyword('UNIQUE')
  PRIMARY = keyword('PRIMARY')
  AUTO_INCREMENT = keyword('AUTO_INCREMENT')
  DEFAULT = keyword('DEFAULT')
  COMMENT = keyword('COMMENT')
  IF = keyword('IF')
  EXISTS = keyword('EXISTS')
  TEMPORARY = keyword('TEMPORARY')
  ENGINE = keyword('ENGINE')
  CHARSET = keyword('CHARSET')

  AAAA = keyword('AAAA')

  backtick = anything:char &{ char.charCodeAt(0) is 96 } -> char
  # fixme: this is bad


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

  create_table = CREATE space {@table_flags = blankObj()} tbl_is_temporary? TABLE space+ sql_name:table_name
                 tbl_if_not_exists?
                 "(" spaces repeat1n('create_def'):defs ")"
                 spaces tbl_engine? spaces tbl_default_charset? spaces tbl_comment?
                 -> ['CreateTable', table_name, defs, @table_flags, @handleComments() ]

  create_def = sql_name:col_name spaces column_definition:col_def -> ['CreateDef', col_name, col_def, @handleComments()]
             | ( INDEX | KEY ) spaces sql_name:index_name "(" spaces repeat1n('sql_name'):index_columns ")" -> ['CreateIndex', index_name, index_columns, @handleComments()]
             | CONSTRAINT spaces sql_name:foreign_key_name FOREIGN space KEY "(" spaces repeat1n('sql_name'):index_columns ")"
               REFERENCES spaces sql_name:foreign_table "(" spaces repeat1n('sql_name'):foreign_columns ")" -> ['CreateForeign', foreign_key_name, index_columns, foreign_table, foreign_columns, @handleComments()]
             | PRIMARY KEY "(" spaces repeat1n('sql_name'):columns ")" -> ['CreatePrimary', columns, @handleComments()]

  column_definition = data_type:data_type
                      (
                        spaces (
                          col_not_null
                        | col_null
                        | col_default_value
                        | col_auto_increment
                        | col_unique_key
                        | col_primary_key
                        | col_comment
                        )
                      )*
                      -> ['ColDef', data_type, @column_flags]

  data_type = {@column_flags = blankObj()}
            (
                ( BIT:type func_call?:params )
              | ( TINYINT | SMALLINT | MEDIUMINT | INT | INTEGER | BIGINT ):type func_call?:params col_unsigned? col_zerofill?
              | ( VARCHAR | CHAR ):type func_call?:params col_binary?
              | ( TINYTEXT | TEXT | MEDIUMTEXT | LONGTEXT ) ''?:params col_binary?
            ) -> ['DataType', type, params, @column_flags]

  col_not_null        = NOT space NULL spaces {@column_flags.not_null = true} -> true
  col_null            = NULL spaces {@column_flags.null = true} -> true
  col_auto_increment  = AUTO_INCREMENT spaces {@column_flags.auto_increment = true} -> true
  col_unsigned        = UNSIGNED spaces {@column_flags.unsigned = true} -> true
  col_zerofill        = ZEROFILL spaces {@column_flags.zerofill = true} -> true
  col_binary          = BINARY spaces {@column_flags.binary = true} -> true

  col_unique_key      = UNIQUE (space KEY)? spaces {@column_flags.unique_key = true} -> true
  col_primary_key     = PRIMARY (space KEY)? spaces {@column_flags.primary_key = true} -> true

  col_default_value   = DEFAULT spaces (NULL | quoted_string):col_default_value {@column_flags.default_value = col_default_value} -> col_default_value
  col_comment         = COMMENT spaces quoted_string:col_comment {@column_flags.comment = col_comment} -> col_comment

  tbl_if_not_exists   = IF space NOT space EXISTS {@table_flags.tbl_if_not_exists = true} -> true
  tbl_is_temporary    = TEMPORARY {@table_flags.temporary = true} -> true
  tbl_engine          = ENGINE "=" "InnoDB":engine {@table_flags.engine = engine} -> engine
  tbl_default_charset = DEFAULT space CHARSET "=" "utf8":charset {@table_flags.charset = charset} -> charset
  tbl_comment         = COMMENT spaces '=' spaces quoted_string:comment {@table_flags.comment = comment} -> comment


a=9
str = '''
CREATE TABLE project ( -- test comment
  id int(11) NOT NULL AUTO_INCREMENT,
  name varchar(255) DEFAULT NULL,
  description text,
  technical_description text, -- 2222
  type int(11) DEFAULT NULL,
  is_archived tinyint(1) NOT NULL DEFAULT '0',
  technology_bucket int(11) DEFAULT NULL,
  created_at int(11) DEFAULT NULL,
  created_by int(11) DEFAULT NULL,
  updated_at int(11) DEFAULT NULL,
  updated_by int(11) DEFAULT NULL,
  pid int(11) DEFAULT NULL,
  theater_id int(11) DEFAULT NULL,
  project_manager int(11) DEFAULT NULL,
  manager int(11) DEFAULT NULL,
  theater_service_delivery_manager int(11) DEFAULT NULL,
  client_theater_id int(11) DEFAULT NULL,
  account_team_primary_poc int(11) DEFAULT NULL,
  account_team_se int(11) DEFAULT NULL,
  business_value int(11) DEFAULT NULL,
  hours_booked int(11) DEFAULT NULL,
  service_type_id int(11) DEFAULT NULL,
  sku_id int(11) DEFAULT NULL,
  is_dsa tinyint(1) DEFAULT NULL,
  practice_team_id int(11) DEFAULT NULL,
  location_id int(11) DEFAULT NULL,
  is_hidden tinyint(1) DEFAULT NULL,
  is_cap_case tinyint(1) DEFAULT NULL,
  wiki_url varchar(1024) DEFAULT NULL,
  other_url varchar(1024) DEFAULT NULL,
  tims_id varchar(255) DEFAULT NULL,
  is_free tinyint(1) DEFAULT NULL,
  PRIMARY KEY (id),
  KEY projects_technology_buckets_id_fk (technology_bucket),
  KEY projects_project_types_id_fk (type),
  KEY project_theater_id_fk (theater_id),
  KEY project_user_id_pm_fk (project_manager),
  KEY project_user_id_manager_fk (manager),
  KEY project_user_id_delivery_manager_fk (theater_service_delivery_manager),
  KEY project_user_id_primary_poc_fk (account_team_primary_poc),
  KEY project_user_id_team_se_fk (account_team_se),
  CONSTRAINT project_theater_id_fk FOREIGN KEY(theater_id) REFERENCES theater(id),
  CONSTRAINT project_user_id_delivery_manager_fk FOREIGN KEY (theater_service_delivery_manager) REFERENCES user (id),
  CONSTRAINT project_user_id_fk FOREIGN KEY (project_manager) REFERENCES user (id),
  CONSTRAINT project_user_id_manager_fk FOREIGN KEY (manager) REFERENCES user (id),
  CONSTRAINT project_user_id_pm_fk FOREIGN KEY (project_manager) REFERENCES user (id),
  CONSTRAINT project_user_id_primary_poc_fk FOREIGN KEY (account_team_primary_poc) REFERENCES user (id),
  CONSTRAINT project_user_id_team_se_fk FOREIGN KEY (account_team_se) REFERENCES user (id),
  CONSTRAINT projects_project_types_id_fk FOREIGN KEY (type) REFERENCES project_type (id),
  CONSTRAINT projects_technology_buckets_id_fk FOREIGN KEY (technology_bucket) REFERENCES project_technology_bucket (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='asdf'
'''


console.log SQLCreateTableParser.matchAll(str, 'create_table')[2]

#str = 'PPp'
#console.log SQLCreateTableParser.matchAll str, 'testing'

#str = '`'
#console.log SQLCreateTableParser.matchAll str, 'backtick'