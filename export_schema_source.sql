-- ============================================================================
-- Oracle User / Privilege Export Script
-- Run on SOURCE database as a sufficiently privileged user.
--
-- Usage:
--   sqlplus / as sysdba
--   @export_user.sql
--
-- Change USER_NAME below.
--
-- Output:
--   export_<USER_NAME>.sql
--
-- The generated file can be reviewed and executed on the TARGET database.
--
-- NOTE:
--   This script exports USER/GRANTS/QUOTAS/PROFILE information.
--   It does NOT export objects owned by the user.
--   Use Data Pump (expdp/impdp) if you also need tables, indexes,
--   procedures, sequences, synonyms, data, etc.
-- ============================================================================

SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET VERIFY OFF
SET TERMOUT ON
SET PAGESIZE 0
SET LINESIZE 32767
SET LONG 1000000
SET LONGCHUNKSIZE 1000000
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

DEFINE USER_NAME = 'SCHEMA_NAME'

COLUMN export_file NEW_VALUE export_file NOPRINT

SELECT 'export_' || LOWER('&USER_NAME') || '.sql' AS export_file
FROM dual;

SPOOL &export_file

PROMPT ============================================================================
PROMPT USER EXPORT
PROMPT USER: &USER_NAME
PROMPT ============================================================================


PROMPT
PROMPT ============================================================================
PROMPT CREATE USER
PROMPT ============================================================================

SELECT
    'CREATE USER "' || username || '"' ||
    CASE
        WHEN password IS NOT NULL
        THEN ' IDENTIFIED BY VALUES ''' ||
             REPLACE(password, '''', '''''') || ''''
        ELSE ' IDENTIFIED BY "CHANGE_ME_PASSWORD"'
    END ||
    ' DEFAULT TABLESPACE "' || default_tablespace || '"' ||
    ' TEMPORARY TABLESPACE "' || temporary_tablespace || '"' ||
    ';'
FROM dba_users
WHERE username = UPPER('&USER_NAME');


PROMPT
PROMPT ============================================================================
PROMPT ACCOUNT STATUS
PROMPT ============================================================================

SELECT
    CASE
        WHEN account_status LIKE '%LOCKED%'
        THEN 'ALTER USER "' || username || '" ACCOUNT LOCK;'
        ELSE 'ALTER USER "' || username || '" ACCOUNT UNLOCK;'
    END
FROM dba_users
WHERE username = UPPER('&USER_NAME');


PROMPT
PROMPT ============================================================================
PROMPT PROFILE
PROMPT ============================================================================

SELECT
    'ALTER USER "' || username ||
    '" PROFILE "' || profile || '";'
FROM dba_users
WHERE username = UPPER('&USER_NAME');


PROMPT
PROMPT ============================================================================
PROMPT SYSTEM PRIVILEGES
PROMPT ============================================================================

SELECT
    'GRANT ' || privilege ||
    ' TO "' || grantee || '"' ||
    CASE
        WHEN admin_option = 'YES'
        THEN ' WITH ADMIN OPTION'
        ELSE ''
    END ||
    ';'
FROM dba_sys_privs
WHERE grantee = UPPER('&USER_NAME')
ORDER BY privilege;


PROMPT
PROMPT ============================================================================
PROMPT ROLE GRANTS
PROMPT ============================================================================

SELECT
    'GRANT "' || granted_role ||
    '" TO "' || grantee || '"' ||
    CASE
        WHEN admin_option = 'YES'
        THEN ' WITH ADMIN OPTION'
        ELSE ''
    END ||
    ';'
FROM dba_role_privs
WHERE grantee = UPPER('&USER_NAME')
ORDER BY granted_role;


PROMPT
PROMPT ============================================================================
PROMPT DEFAULT ROLE CONFIGURATION
PROMPT ============================================================================

SELECT
    CASE
        WHEN default_role = 'YES'
        THEN
            'ALTER USER "' || grantee ||
            '" DEFAULT ROLE "' || granted_role || '";'
        ELSE
            '-- Role "' || granted_role || '" is NOT a default role'
    END
FROM dba_role_privs
WHERE grantee = UPPER('&USER_NAME')
ORDER BY granted_role;


PROMPT
PROMPT ============================================================================
PROMPT OBJECT PRIVILEGES
PROMPT ============================================================================

SELECT
    'GRANT ' || privilege ||
    ' ON "' || owner || '"."' || table_name ||
    '" TO "' || grantee || '"' ||
    CASE
        WHEN grantable = 'YES'
        THEN ' WITH GRANT OPTION'
        ELSE ''
    END ||
    ';'
FROM dba_tab_privs
WHERE grantee = UPPER('&USER_NAME')
ORDER BY owner, table_name, privilege;


PROMPT
PROMPT ============================================================================
PROMPT COLUMN PRIVILEGES
PROMPT ============================================================================

SELECT
    'GRANT ' || privilege ||
    ' ("' || column_name || '") ON "' ||
    owner || '"."' || table_name ||
    '" TO "' || grantee || '"' ||
    CASE
        WHEN grantable = 'YES'
        THEN ' WITH GRANT OPTION'
        ELSE ''
    END ||
    ';'
FROM dba_col_privs
WHERE grantee = UPPER('&USER_NAME')
ORDER BY owner, table_name, column_name, privilege;


PROMPT
PROMPT ============================================================================
PROMPT TABLESPACE QUOTAS
PROMPT ============================================================================

SELECT
    'ALTER USER "' || username ||
    '" QUOTA ' ||
    CASE
        WHEN max_bytes = -1
        THEN 'UNLIMITED'
        ELSE TO_CHAR(max_bytes)
    END ||
    ' ON "' || tablespace_name || '";'
FROM dba_ts_quotas
WHERE username = UPPER('&USER_NAME')
ORDER BY tablespace_name;


PROMPT
PROMPT ============================================================================
PROMPT PROXY USERS
PROMPT ============================================================================

SELECT
    'ALTER USER "' || client ||
    '" GRANT CONNECT THROUGH "' ||
    proxy || '"' ||
    CASE
        WHEN proxy_type = 'ENTERPRISE USER'
        THEN ' WITH ENTERPRISE USER CLAUSE'
        ELSE ''
    END ||
    ';'
FROM proxy_users
WHERE client = UPPER('&USER_NAME')
   OR proxy = UPPER('&USER_NAME')
ORDER BY proxy, client;


PROMPT
PROMPT ============================================================================
PROMPT USER ROLE HIERARCHY / PRIVILEGES
PROMPT ============================================================================
PROMPT
PROMPT NOTE:
PROMPT Roles granted to BDUSER are exported above.
PROMPT Privileges granted to those roles are NOT duplicated here.
PROMPT They remain associated with the roles themselves.
PROMPT


PROMPT
PROMPT ============================================================================
PROMPT USER VALIDATION
PROMPT ============================================================================

SELECT
    '-- USER: ' || username ||
    ' | STATUS: ' || account_status ||
    ' | PROFILE: ' || profile ||
    ' | DEFAULT_TS: ' || default_tablespace ||
    ' | TEMP_TS: ' || temporary_tablespace
FROM dba_users
WHERE username = UPPER('&USER_NAME');


PROMPT
PROMPT ============================================================================
PROMPT END OF USER EXPORT
PROMPT ============================================================================

SPOOL OFF

SET HEADING ON
SET FEEDBACK ON
SET VERIFY ON
SET TERMOUT ON

PROMPT
PROMPT ============================================================================
PROMPT Export completed.
PROMPT File: &export_file
PROMPT ============================================================================
