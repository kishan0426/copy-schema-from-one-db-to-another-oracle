
CREATE OR REPLACE PROCEDURE COPY_SCHEMA
(
    P_SOURCE_SCHEMA IN VARCHAR2,
    P_TARGET_SCHEMA IN VARCHAR2,
    P_DB_LINK       IN VARCHAR2,
    P_PARALLEL      IN NUMBER   DEFAULT 4,
    P_NOLOGGING     IN VARCHAR2 DEFAULT 'Y'
)
AUTHID CURRENT_USER
AS
    V_HANDLE       NUMBER;
    V_JOB_STATE    VARCHAR2(30);
    V_JOB_NAME     VARCHAR2(30);
    V_SOURCE       VARCHAR2(128);
    V_TARGET       VARCHAR2(128);
    V_LINK         VARCHAR2(128);

BEGIN

    ------------------------------------------------
    -- VALIDATE PARAMETERS
    ------------------------------------------------

    IF P_PARALLEL < 1 THEN
        RAISE_APPLICATION_ERROR(
            -20001, 'Invalid parallel degree'
        );
    END IF;

    IF UPPER(P_NOLOGGING) NOT IN ('Y','N') THEN
        RAISE_APPLICATION_ERROR(
            -20002, 'NOLOGGING must be Y or N'
        );
    END IF;

    V_SOURCE := DBMS_ASSERT.SCHEMA_NAME(
                    UPPER(P_SOURCE_SCHEMA)
                );

    V_TARGET := DBMS_ASSERT.SCHEMA_NAME(
                    UPPER(P_TARGET_SCHEMA)
                );

    V_LINK := DBMS_ASSERT.SIMPLE_SQL_NAME(
                  P_DB_LINK
              );

    V_JOB_NAME :=
        'COPY_' || SUBSTR(RAWTOHEX(SYS_GUID()),1,20);

    DBMS_OUTPUT.PUT_LINE('================================');
    DBMS_OUTPUT.PUT_LINE('SCHEMA COPY STARTED');
    DBMS_OUTPUT.PUT_LINE('SOURCE SCHEMA : ' || V_SOURCE);
    DBMS_OUTPUT.PUT_LINE('TARGET SCHEMA : ' || V_TARGET);
    DBMS_OUTPUT.PUT_LINE('DB LINK       : ' || V_LINK);
    DBMS_OUTPUT.PUT_LINE('PARALLEL      : ' || P_PARALLEL);
    DBMS_OUTPUT.PUT_LINE('NOLOGGING     : ' || P_NOLOGGING);
    DBMS_OUTPUT.PUT_LINE('JOB NAME      : ' || V_JOB_NAME);
    DBMS_OUTPUT.PUT_LINE('================================');

    ------------------------------------------------
    -- OPEN NETWORK IMPORT JOB
    ------------------------------------------------

    V_HANDLE := DBMS_DATAPUMP.OPEN
    (
        OPERATION   => 'IMPORT',
        JOB_MODE    => 'SCHEMA',
        REMOTE_LINK => V_LINK,
        JOB_NAME    => V_JOB_NAME
    );

    ------------------------------------------------
    -- SOURCE SCHEMA FILTER
    ------------------------------------------------

    DBMS_DATAPUMP.METADATA_FILTER
    (
        V_HANDLE,
        'SCHEMA_EXPR',
        'IN (''' || V_SOURCE || ''')'
    );

    ------------------------------------------------
    -- REMAP SOURCE SCHEMA TO TARGET SCHEMA
    ------------------------------------------------

    IF V_SOURCE <> V_TARGET THEN

        DBMS_DATAPUMP.METADATA_REMAP
        (
            V_HANDLE,
            'REMAP_SCHEMA',
            V_SOURCE,
            V_TARGET
        );

    END IF;

    ------------------------------------------------
    -- SKIP EXISTING TABLES
    ------------------------------------------------

    DBMS_DATAPUMP.SET_PARAMETER
    (
        V_HANDLE,
        'TABLE_EXISTS_ACTION',
        'SKIP'
    );

    ------------------------------------------------
    -- PARALLEL EXECUTION
    ------------------------------------------------

    DBMS_DATAPUMP.SET_PARALLEL
    (
        V_HANDLE,
        P_PARALLEL
    );

    ------------------------------------------------
    -- NOLOGGING FOR TABLES AND INDEXES
    ------------------------------------------------

    IF UPPER(P_NOLOGGING) = 'Y' THEN

        DBMS_DATAPUMP.METADATA_TRANSFORM
        (
            V_HANDLE,
            'DISABLE_ARCHIVE_LOGGING',
            1
        );

    END IF;

    ------------------------------------------------
    -- START IMPORT
    ------------------------------------------------

    DBMS_OUTPUT.PUT_LINE('STARTING IMPORT JOB...');

    DBMS_DATAPUMP.START_JOB(V_HANDLE);

    ------------------------------------------------
    -- WAIT UNTIL IMPORT COMPLETES
    ------------------------------------------------

    DBMS_DATAPUMP.WAIT_FOR_JOB
    (
        V_HANDLE,
        V_JOB_STATE
    );

    DBMS_OUTPUT.PUT_LINE('================================');
    DBMS_OUTPUT.PUT_LINE('IMPORT JOB FINISHED');
    DBMS_OUTPUT.PUT_LINE('JOB STATE: ' || V_JOB_STATE);
    DBMS_OUTPUT.PUT_LINE('JOB NAME : ' || V_JOB_NAME);
    DBMS_OUTPUT.PUT_LINE('================================');

    IF V_JOB_STATE <> 'COMPLETED' THEN

        RAISE_APPLICATION_ERROR(
            -20003,
            'Data Pump job did not complete successfully. State: '
            || V_JOB_STATE
        );

    END IF;

EXCEPTION
    WHEN OTHERS THEN

        DBMS_OUTPUT.PUT_LINE(
            'COPY ERROR: ' || SQLERRM
        );

        IF V_HANDLE IS NOT NULL THEN
            BEGIN
                DBMS_DATAPUMP.STOP_JOB(
                    V_HANDLE,
                    1,
                    0,
                    0
                );
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;
        END IF;

        RAISE;

END;
/
