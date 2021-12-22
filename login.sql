/* print out anything when we log in */
set termout off

/* DBMS_OUTPUT.PUT_LINE set on and as big as possible */
set serveroutput on size 1000000 format wrapped

/* column width */
set lines 256
set trimout on
set tab off
set pagesize 100
set colsep " | "
column FILENAME format a50

/* removing training blanks from spool */
set trimspool on

# default to 80 for LONG or CLOB */
set long 5000

/* default widht at which sqlplus wraps out */
set linesize 149

# default print column heading every 14 lines
set pagesize 9999

/* signature */
column global_name new_value gname
set termout off
define sql_prompt=idle
column user_sid new_value sql_prompt
select lower(user) || '@' || lower('&_CONNECT_IDENTIFIER') user_sid from dual;
column cust_env new_value sql_prompt2
select lower(env_name) cust_env from idsdba.ids_config;
set sqlprompt '&sql_prompt-&sql_prompt2>'

/* sqlplus can now print to the screen */
set termout on
