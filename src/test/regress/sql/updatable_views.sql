CREATE USER regress_view_user1 PASSWORD 'Gauss@123';
CREATE USER regress_view_user2 PASSWORD 'Gauss@123';

-- nested-view permissions check
CREATE TABLE base_tbl(a int, b text, c float);
INSERT INTO base_tbl VALUES (1, 'Row 1', 1.0);

SET SESSION AUTHORIZATION regress_view_user1 PASSWORD 'Gauss@123';
CREATE VIEW rw_view1 AS SELECT * FROM base_tbl;
GRANT ALL ON SCHEMA regress_view_user1 TO regress_view_user2;
SELECT * FROM rw_view1;  -- not allowed
SELECT * FROM rw_view1 FOR UPDATE;  -- not allowed
UPDATE rw_view1 SET b = 'foo' WHERE a = 1;  -- not allowed

SET SESSION AUTHORIZATION regress_view_user2 PASSWORD 'Gauss@123';
CREATE VIEW rw_view2 AS SELECT * FROM regress_view_user1.rw_view1;
SELECT * FROM rw_view2;  -- not allowed
SELECT * FROM rw_view2 FOR UPDATE;  -- not allowed
UPDATE rw_view2 SET b = 'bar' WHERE a = 1;  -- not allowed

RESET SESSION AUTHORIZATION;
GRANT SELECT ON base_tbl TO regress_view_user1;

SET SESSION AUTHORIZATION regress_view_user1 PASSWORD 'Gauss@123';
SELECT * FROM rw_view1;
SELECT * FROM rw_view1 FOR UPDATE;  -- not allowed
UPDATE rw_view1 SET b = 'foo' WHERE a = 1;  -- unlike pgsql, we do not support updating views

SET SESSION AUTHORIZATION regress_view_user2 PASSWORD 'Gauss@123';
SELECT * FROM rw_view2;  -- not allowed
SELECT * FROM rw_view2 FOR UPDATE;  -- not allowed
UPDATE rw_view2 SET b = 'bar' WHERE a = 1;  -- not allowed

SET SESSION AUTHORIZATION regress_view_user1 PASSWORD 'Gauss@123';
GRANT SELECT ON rw_view1 TO regress_view_user2;

SET SESSION AUTHORIZATION regress_view_user2 PASSWORD 'Gauss@123';
SELECT * FROM rw_view2;
SELECT * FROM rw_view2 FOR UPDATE;  -- not allowed
UPDATE rw_view2 SET b = 'bar' WHERE a = 1;  -- unlike pgsql, we do not support updating views

RESET SESSION AUTHORIZATION;
GRANT UPDATE ON base_tbl TO regress_view_user1;

SET SESSION AUTHORIZATION regress_view_user1 PASSWORD 'Gauss@123';
SELECT * FROM rw_view1;
SELECT * FROM rw_view1 FOR UPDATE;
UPDATE rw_view1 SET b = 'foo' WHERE a = 1;  -- unlike pgsql, we do not support updating views

SET SESSION AUTHORIZATION regress_view_user2 PASSWORD 'Gauss@123';
SELECT * FROM rw_view2;
SELECT * FROM rw_view2 FOR UPDATE;  -- not allowed
UPDATE rw_view2 SET b = 'bar' WHERE a = 1;  -- unlike pgsql, we do not support updating views

SET SESSION AUTHORIZATION regress_view_user1 PASSWORD 'Gauss@123';
GRANT UPDATE ON rw_view1 TO regress_view_user2;

SET SESSION AUTHORIZATION regress_view_user2 PASSWORD 'Gauss@123';
SELECT * FROM rw_view2;
SELECT * FROM rw_view2 FOR UPDATE;
UPDATE rw_view2 SET b = 'bar' WHERE a = 1;  -- unlike pgsql, we do not support updating views

RESET SESSION AUTHORIZATION;
REVOKE UPDATE ON base_tbl FROM regress_view_user1;

SET SESSION AUTHORIZATION regress_view_user1 PASSWORD 'Gauss@123';
SELECT * FROM rw_view1;
SELECT * FROM rw_view1 FOR UPDATE;  -- not allowed
UPDATE rw_view1 SET b = 'foo' WHERE a = 1;  -- unlike pgsql, we do not support updating views

SET SESSION AUTHORIZATION regress_view_user2 PASSWORD 'Gauss@123';
SELECT * FROM rw_view2;
SELECT * FROM rw_view2 FOR UPDATE;  -- not allowed
UPDATE rw_view2 SET b = 'bar' WHERE a = 1;  -- unlike pgsql, we do not support updating views

RESET SESSION AUTHORIZATION;

DROP TABLE base_tbl CASCADE;

DROP USER regress_view_user1;
DROP USER regress_view_user2;

--
-- UPDATABLE VIEWS
--

-- check that non-updatable views and columns are rejected with useful error messages

CREATE TABLE base_tbl (a int PRIMARY KEY, b text DEFAULT 'Unspecified');
INSERT INTO base_tbl SELECT i, 'Row ' || i FROM generate_series(-2, 2) g(i);

CREATE VIEW ro_view1 AS SELECT DISTINCT a, b FROM base_tbl; -- DISTINCT not supported
CREATE VIEW ro_view2 AS SELECT a, b FROM base_tbl GROUP BY a, b; -- GROUP BY not supported
CREATE VIEW ro_view3 AS SELECT 1 FROM base_tbl HAVING max(a) > 0; -- HAVING not supported
CREATE VIEW ro_view4 AS SELECT count(*) FROM base_tbl; -- Aggregate functions not supported
CREATE VIEW ro_view5 AS SELECT a, rank() OVER() FROM base_tbl; -- Window functions not supported
CREATE VIEW ro_view6 AS SELECT a, b FROM base_tbl UNION SELECT -a, b FROM base_tbl; -- Set ops not supported
CREATE VIEW ro_view7 AS WITH t AS (SELECT a, b FROM base_tbl) SELECT * FROM t; -- WITH not supported
CREATE VIEW ro_view8 AS SELECT a, b FROM base_tbl ORDER BY a OFFSET 1; -- OFFSET not supported
CREATE VIEW ro_view9 AS SELECT a, b FROM base_tbl ORDER BY a LIMIT 1; -- LIMIT not supported
CREATE VIEW ro_view10 AS SELECT 1 AS a; -- No base relations
CREATE VIEW ro_view11 AS SELECT b1.a, b2.b FROM base_tbl b1, base_tbl b2; -- Multiple base relations
CREATE VIEW ro_view12 AS SELECT * FROM generate_series(1, 10) AS g(a); -- SRF in rangetable
CREATE VIEW ro_view13 AS SELECT a, b FROM (SELECT * FROM base_tbl) AS t; -- Subselect in rangetable
CREATE VIEW rw_view14 AS SELECT ctid, a, b FROM base_tbl; -- System columns may be part of an updatable view
CREATE VIEW rw_view15 AS SELECT a, upper(b) FROM base_tbl; -- Expression/function may be part of an updatable view
CREATE VIEW rw_view16 AS SELECT a, b, a AS aa FROM base_tbl; -- Repeated column may be part of an updatable view
CREATE VIEW ro_view17 AS SELECT * FROM ro_view1; -- Base relation not updatable
CREATE VIEW ro_view18 AS SELECT * FROM (VALUES(1)) AS tmp(a); -- VALUES in rangetable
CREATE SEQUENCE seq;
CREATE VIEW ro_view19 AS SELECT * FROM seq; -- View based on a sequence
CREATE VIEW ro_view20 AS SELECT a, b, generate_series(1, a) g FROM base_tbl; -- SRF in targetlist not supported

SELECT table_name, is_insertable_into
  FROM information_schema.tables
 WHERE table_name LIKE E'r_\\_view%'
 ORDER BY table_name;

SELECT table_name, is_updatable, is_insertable_into
  FROM information_schema.views
 WHERE table_name LIKE E'r_\\_view%'
 ORDER BY table_name;

SELECT table_name, column_name, is_updatable
  FROM information_schema.columns
 WHERE table_name LIKE E'r_\\_view%'
 ORDER BY table_name, ordinal_position;

-- Read-only views
DELETE FROM ro_view1;
DELETE FROM ro_view2;
DELETE FROM ro_view3;
DELETE FROM ro_view4;
DELETE FROM ro_view5;
DELETE FROM ro_view6;
UPDATE ro_view7 SET a=a+1;
UPDATE ro_view8 SET a=a+1;
UPDATE ro_view9 SET a=a+1;
UPDATE ro_view10 SET a=a+1;
UPDATE ro_view11 SET a=a+1;
UPDATE ro_view12 SET a=a+1;
INSERT INTO ro_view13 VALUES (3, 'Row 3');
-- Partially updatable view
INSERT INTO rw_view14 VALUES (null, 3, 'Row 3'); -- should fail
INSERT INTO rw_view14 (a, b) VALUES (3, 'Row 3'); -- should be OK
UPDATE rw_view14 SET ctid=null WHERE a=3; -- should fail
UPDATE rw_view14 SET b='ROW 3' WHERE a=3; -- should be OK
SELECT * FROM base_tbl;
DELETE FROM rw_view14 WHERE a=3; -- should be OK
-- Partially updatable view
INSERT INTO rw_view15 VALUES (3, 'ROW 3'); -- should fail
INSERT INTO rw_view15 (a) VALUES (3); -- should be OK
ALTER VIEW rw_view15 ALTER COLUMN upper SET DEFAULT 'NOT SET';
INSERT INTO rw_view15 (a) VALUES (4); -- should fail
UPDATE rw_view15 SET upper='ROW 3' WHERE a=3; -- should fail
UPDATE rw_view15 SET upper=DEFAULT WHERE a=3; -- should fail
UPDATE rw_view15 SET a=4 WHERE a=3; -- should be OK
SELECT * FROM base_tbl;
DELETE FROM rw_view15 WHERE a=4; -- should be OK
-- Partially updatable view
INSERT INTO rw_view16 VALUES (3, 'Row 3', 3); -- should fail
INSERT INTO rw_view16 (a, b) VALUES (3, 'Row 3'); -- should be OK
UPDATE rw_view16 SET a=3, aa=-3 WHERE a=3; -- should fail
UPDATE rw_view16 SET aa=-3 WHERE a=3; -- should be OK
SELECT * FROM base_tbl;
DELETE FROM rw_view16 WHERE a=-3; -- should be OK
-- Read-only views
INSERT INTO ro_view17 VALUES (3, 'ROW 3');
DELETE FROM ro_view18;
UPDATE ro_view19 SET max_value=1000;
UPDATE ro_view20 SET b=upper(b);

-- A view with a conditional INSTEAD rule but no unconditional INSTEAD rules
-- or INSTEAD OF triggers should be non-updatable and generate useful error
-- messages with appropriate detail
CREATE RULE rw_view16_ins_rule AS ON INSERT TO rw_view16
  WHERE NEW.a > 0 DO INSTEAD INSERT INTO base_tbl VALUES (NEW.a, NEW.b);
CREATE RULE rw_view16_upd_rule AS ON UPDATE TO rw_view16
  WHERE OLD.a > 0 DO INSTEAD UPDATE base_tbl SET b=NEW.b WHERE a=OLD.a;
CREATE RULE rw_view16_del_rule AS ON DELETE TO rw_view16
  WHERE OLD.a > 0 DO INSTEAD DELETE FROM base_tbl WHERE a=OLD.a;

INSERT INTO rw_view16 (a, b) VALUES (3, 'Row 3'); -- should fail
UPDATE rw_view16 SET b='ROW 2' WHERE a=2; -- should fail
DELETE FROM rw_view16 WHERE a=2; -- should fail

DROP TABLE base_tbl CASCADE;
DROP VIEW ro_view10, ro_view12, ro_view18;
DROP SEQUENCE seq CASCADE;

-- simple updatable view

CREATE TABLE base_tbl (a int PRIMARY KEY, b text DEFAULT 'Unspecified');
INSERT INTO base_tbl SELECT i, 'Row ' || i FROM generate_series(-2, 2) g(i);

CREATE VIEW rw_view1 AS SELECT * FROM base_tbl WHERE a>0;

SELECT table_name, is_insertable_into
  FROM information_schema.tables
 WHERE table_name = 'rw_view1';

SELECT table_name, is_updatable, is_insertable_into
  FROM information_schema.views
 WHERE table_name = 'rw_view1';

SELECT table_name, column_name, is_updatable
  FROM information_schema.columns
 WHERE table_name = 'rw_view1'
 ORDER BY ordinal_position;

INSERT INTO rw_view1 VALUES (3, 'Row 3');
INSERT INTO rw_view1 (a) VALUES (4);
UPDATE rw_view1 SET a=5 WHERE a=4;
DELETE FROM rw_view1 WHERE b='Row 2';
SELECT * FROM base_tbl;

EXPLAIN (costs off) UPDATE rw_view1 SET a=6 WHERE a=5;
EXPLAIN (costs off) DELETE FROM rw_view1 WHERE a=5;

-- it's still updatable if we add a DO ALSO rule

CREATE TABLE base_tbl_hist(ts timestamptz default now(), a int, b text);

CREATE RULE base_tbl_log AS ON INSERT TO rw_view1 DO ALSO
  INSERT INTO base_tbl_hist(a,b) VALUES(new.a, new.b);

SELECT table_name, is_updatable, is_insertable_into
  FROM information_schema.views
 WHERE table_name = 'rw_view1';

-- Check behavior with DEFAULTs

INSERT INTO rw_view1 VALUES (9, DEFAULT), (10, DEFAULT);
SELECT a, b FROM base_tbl_hist;

DROP TABLE base_tbl CASCADE;
DROP TABLE base_tbl_hist;

-- view on top of view

CREATE TABLE base_tbl (a int PRIMARY KEY, b text DEFAULT 'Unspecified');
INSERT INTO base_tbl SELECT i, 'Row ' || i FROM generate_series(-2, 2) g(i);

CREATE VIEW rw_view1 AS SELECT b AS bb, a AS aa FROM base_tbl WHERE a>0;
CREATE VIEW rw_view2 AS SELECT aa AS aaa, bb AS bbb FROM rw_view1 WHERE aa<10;

SELECT table_name, is_insertable_into
  FROM information_schema.tables
 WHERE table_name = 'rw_view2';

SELECT table_name, is_updatable, is_insertable_into
  FROM information_schema.views
 WHERE table_name = 'rw_view2';

SELECT table_name, column_name, is_updatable
  FROM information_schema.columns
 WHERE table_name = 'rw_view2'
 ORDER BY ordinal_position;

INSERT INTO rw_view2 VALUES (3, 'Row 3');
INSERT INTO rw_view2 (aaa) VALUES (4);
SELECT * FROM rw_view2;
UPDATE rw_view2 SET bbb='Row 4' WHERE aaa=4;
DELETE FROM rw_view2 WHERE aaa=2;
SELECT * FROM rw_view2;

EXPLAIN (costs off) UPDATE rw_view2 SET aaa=5 WHERE aaa=4;
EXPLAIN (costs off) DELETE FROM rw_view2 WHERE aaa=4;

DROP TABLE base_tbl CASCADE;

-- view on top of view with rules

CREATE TABLE base_tbl (a int PRIMARY KEY, b text DEFAULT 'Unspecified');
INSERT INTO base_tbl SELECT i, 'Row ' || i FROM generate_series(-2, 2) g(i);

CREATE VIEW rw_view1 AS SELECT * FROM base_tbl WHERE a>0 OFFSET 0; -- not updatable without rules/triggers
CREATE VIEW rw_view2 AS SELECT * FROM rw_view1 WHERE a<10;

SELECT table_name, is_insertable_into
  FROM information_schema.tables
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name;

SELECT table_name, is_updatable, is_insertable_into
  FROM information_schema.views
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name;

SELECT table_name, column_name, is_updatable
  FROM information_schema.columns
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name, ordinal_position;

CREATE RULE rw_view1_ins_rule AS ON INSERT TO rw_view1
  DO INSTEAD INSERT INTO base_tbl VALUES (NEW.a, NEW.b) RETURNING *;

SELECT table_name, is_insertable_into
  FROM information_schema.tables
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name;

SELECT table_name, is_updatable, is_insertable_into
  FROM information_schema.views
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name;

SELECT table_name, column_name, is_updatable
  FROM information_schema.columns
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name, ordinal_position;

CREATE RULE rw_view1_upd_rule AS ON UPDATE TO rw_view1
  DO INSTEAD UPDATE base_tbl SET b=NEW.b WHERE a=OLD.a RETURNING NEW.*;

SELECT table_name, is_insertable_into
  FROM information_schema.tables
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name;

SELECT table_name, is_updatable, is_insertable_into
  FROM information_schema.views
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name;

SELECT table_name, column_name, is_updatable
  FROM information_schema.columns
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name, ordinal_position;

CREATE RULE rw_view1_del_rule AS ON DELETE TO rw_view1
  DO INSTEAD DELETE FROM base_tbl WHERE a=OLD.a RETURNING OLD.*;

SELECT table_name, is_insertable_into
  FROM information_schema.tables
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name;

SELECT table_name, is_updatable, is_insertable_into
  FROM information_schema.views
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name;

SELECT table_name, column_name, is_updatable
  FROM information_schema.columns
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name, ordinal_position;

INSERT INTO rw_view2 VALUES (3, 'Row 3') RETURNING *;
UPDATE rw_view2 SET b='Row three' WHERE a=3 RETURNING *;
SELECT * FROM rw_view2;
DELETE FROM rw_view2 WHERE a=3 RETURNING *;
SELECT * FROM rw_view2;

EXPLAIN (costs off) UPDATE rw_view2 SET a=3 WHERE a=2;
EXPLAIN (costs off) DELETE FROM rw_view2 WHERE a=2;

DROP TABLE base_tbl CASCADE;

-- view on top of view with triggers

CREATE TABLE base_tbl (a int PRIMARY KEY, b text DEFAULT 'Unspecified');
INSERT INTO base_tbl SELECT i, 'Row ' || i FROM generate_series(-2, 2) g(i);

CREATE VIEW rw_view1 AS SELECT * FROM base_tbl WHERE a>0 OFFSET 0; -- not updatable without rules/triggers
CREATE VIEW rw_view2 AS SELECT * FROM rw_view1 WHERE a<10;

SELECT table_name, is_insertable_into
  FROM information_schema.tables
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name;

SELECT table_name, is_updatable, is_insertable_into,
       is_trigger_updatable, is_trigger_deletable,
       is_trigger_insertable_into
  FROM information_schema.views
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name;

SELECT table_name, column_name, is_updatable
  FROM information_schema.columns
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name, ordinal_position;

CREATE FUNCTION rw_view1_trig_fn()
RETURNS trigger AS
$$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO base_tbl VALUES (NEW.a, NEW.b);
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE base_tbl SET b=NEW.b WHERE a=OLD.a;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    DELETE FROM base_tbl WHERE a=OLD.a;
    RETURN OLD;
  END IF;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER rw_view1_ins_trig INSTEAD OF INSERT ON rw_view1
  FOR EACH ROW EXECUTE PROCEDURE rw_view1_trig_fn();

SELECT table_name, is_insertable_into
  FROM information_schema.tables
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name;

SELECT table_name, is_updatable, is_insertable_into,
       is_trigger_updatable, is_trigger_deletable,
       is_trigger_insertable_into
  FROM information_schema.views
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name;

SELECT table_name, column_name, is_updatable
  FROM information_schema.columns
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name, ordinal_position;

CREATE TRIGGER rw_view1_upd_trig INSTEAD OF UPDATE ON rw_view1
  FOR EACH ROW EXECUTE PROCEDURE rw_view1_trig_fn();

SELECT table_name, is_insertable_into
  FROM information_schema.tables
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name;

SELECT table_name, is_updatable, is_insertable_into,
       is_trigger_updatable, is_trigger_deletable,
       is_trigger_insertable_into
  FROM information_schema.views
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name;

SELECT table_name, column_name, is_updatable
  FROM information_schema.columns
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name, ordinal_position;

CREATE TRIGGER rw_view1_del_trig INSTEAD OF DELETE ON rw_view1
  FOR EACH ROW EXECUTE PROCEDURE rw_view1_trig_fn();

SELECT table_name, is_insertable_into
  FROM information_schema.tables
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name;

SELECT table_name, is_updatable, is_insertable_into,
       is_trigger_updatable, is_trigger_deletable,
       is_trigger_insertable_into
  FROM information_schema.views
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name;

SELECT table_name, column_name, is_updatable
  FROM information_schema.columns
 WHERE table_name LIKE 'rw_view%'
 ORDER BY table_name, ordinal_position;

INSERT INTO rw_view2 VALUES (3, 'Row 3') RETURNING *;
UPDATE rw_view2 SET b='Row three' WHERE a=3 RETURNING *;
SELECT * FROM rw_view2;
DELETE FROM rw_view2 WHERE a=3 RETURNING *;
SELECT * FROM rw_view2;

EXPLAIN (costs off) UPDATE rw_view2 SET a=3 WHERE a=2;
EXPLAIN (costs off) DELETE FROM rw_view2 WHERE a=2;

DROP TABLE base_tbl CASCADE;
DROP FUNCTION rw_view1_trig_fn();

-- update using whole row from view

CREATE TABLE base_tbl (a int PRIMARY KEY, b text DEFAULT 'Unspecified');
INSERT INTO base_tbl SELECT i, 'Row ' || i FROM generate_series(-2, 2) g(i);

CREATE VIEW rw_view1 AS SELECT b AS bb, a AS aa FROM base_tbl;

CREATE FUNCTION rw_view1_aa(x rw_view1)
  RETURNS int AS $$ SELECT x.aa $$ LANGUAGE sql;

UPDATE rw_view1 v SET bb='Updated row 2' WHERE rw_view1_aa(v)=2
  RETURNING rw_view1_aa(v), v.bb;
SELECT * FROM base_tbl;

EXPLAIN (costs off)
UPDATE rw_view1 v SET bb='Updated row 2' WHERE rw_view1_aa(v)=2
  RETURNING rw_view1_aa(v), v.bb;

DROP TABLE base_tbl CASCADE;

-- permissions checks

CREATE USER view_user1 PASSWORD 'Gauss@123';
CREATE USER view_user2 PASSWORD 'Gauss@123';

SET SESSION AUTHORIZATION view_user1 PASSWORD 'Gauss@123';
CREATE TABLE base_tbl(a int, b text, c float);
INSERT INTO base_tbl VALUES (1, 'Row 1', 1.0);
CREATE VIEW rw_view1 AS SELECT b AS bb, c AS cc, a AS aa FROM base_tbl;
INSERT INTO rw_view1 VALUES ('Row 2', 2.0, 2);

GRANT USAGE ON SCHEMA view_user1 to view_user2;
GRANT SELECT ON base_tbl TO view_user2;
GRANT SELECT ON rw_view1 TO view_user2;
GRANT UPDATE (a,c) ON base_tbl TO view_user2;
GRANT UPDATE (bb,cc) ON rw_view1 TO view_user2;
RESET SESSION AUTHORIZATION;

SET SESSION AUTHORIZATION view_user2 PASSWORD 'Gauss@123';
CREATE VIEW rw_view2 AS SELECT b AS bb, c AS cc, a AS aa FROM view_user1.base_tbl;
SELECT * FROM view_user1.base_tbl; -- ok
SELECT * FROM view_user1.rw_view1; -- ok
SELECT * FROM rw_view2; -- ok

INSERT INTO view_user1.base_tbl VALUES (3, 'Row 3', 3.0); -- not allowed
INSERT INTO view_user1.rw_view1 VALUES ('Row 3', 3.0, 3); -- not allowed
INSERT INTO rw_view2 VALUES ('Row 3', 3.0, 3); -- not allowed

UPDATE view_user1.base_tbl SET a=a, c=c; -- ok
UPDATE view_user1.base_tbl SET b=b; -- not allowed
UPDATE view_user1.rw_view1 SET bb=bb, cc=cc; -- ok
UPDATE view_user1.rw_view1 SET aa=aa; -- not allowed
UPDATE rw_view2 SET aa=aa, cc=cc; -- ok
UPDATE rw_view2 SET bb=bb; -- not allowed

DELETE FROM view_user1.base_tbl; -- not allowed
DELETE FROM view_user1.rw_view1; -- not allowed
DELETE FROM rw_view2; -- not allowed
RESET SESSION AUTHORIZATION;

SET SESSION AUTHORIZATION view_user1 PASSWORD 'Gauss@123';
GRANT INSERT, DELETE ON base_tbl TO view_user2;
RESET SESSION AUTHORIZATION;

SET SESSION AUTHORIZATION view_user2 PASSWORD 'Gauss@123';
INSERT INTO view_user1.base_tbl VALUES (3, 'Row 3', 3.0); -- ok
INSERT INTO view_user1.rw_view1 VALUES ('Row 4', 4.0, 4); -- not allowed
INSERT INTO rw_view2 VALUES ('Row 4', 4.0, 4); -- ok
DELETE FROM view_user1.base_tbl WHERE a=1; -- ok
DELETE FROM view_user1.rw_view1 WHERE aa=2; -- not allowed
DELETE FROM rw_view2 WHERE aa=2; -- ok
SELECT * FROM view_user1.base_tbl;
RESET SESSION AUTHORIZATION;

SET SESSION AUTHORIZATION view_user1 PASSWORD 'Gauss@123';
REVOKE INSERT, DELETE ON base_tbl FROM view_user2;
GRANT INSERT, DELETE ON rw_view1 TO view_user2;
RESET SESSION AUTHORIZATION;

SET SESSION AUTHORIZATION view_user2 PASSWORD 'Gauss@123';
INSERT INTO view_user1.base_tbl VALUES (5, 'Row 5', 5.0); -- not allowed
INSERT INTO view_user1.rw_view1 VALUES ('Row 5', 5.0, 5); -- ok
INSERT INTO rw_view2 VALUES ('Row 6', 6.0, 6); -- not allowed
DELETE FROM view_user1.base_tbl WHERE a=3; -- not allowed
DELETE FROM view_user1.rw_view1 WHERE aa=3; -- ok
DELETE FROM rw_view2 WHERE aa=4; -- not allowed
SELECT * FROM view_user1.base_tbl;
RESET SESSION AUTHORIZATION;

DROP TABLE view_user1.base_tbl CASCADE;

DROP USER view_user1;
DROP USER view_user2;

-- column defaults

CREATE TABLE base_tbl (a int PRIMARY KEY, b text DEFAULT 'Unspecified', c serial);
INSERT INTO base_tbl VALUES (1, 'Row 1');
INSERT INTO base_tbl VALUES (2, 'Row 2');
INSERT INTO base_tbl VALUES (3);

CREATE VIEW rw_view1 AS SELECT a AS aa, b AS bb FROM base_tbl;
ALTER VIEW rw_view1 ALTER COLUMN bb SET DEFAULT 'View default';

INSERT INTO rw_view1 VALUES (4, 'Row 4');
INSERT INTO rw_view1 (aa) VALUES (5);

SELECT * FROM base_tbl;

DROP TABLE base_tbl CASCADE;

-- Table having triggers

CREATE TABLE base_tbl (a int PRIMARY KEY, b text DEFAULT 'Unspecified');
INSERT INTO base_tbl VALUES (1, 'Row 1');
INSERT INTO base_tbl VALUES (2, 'Row 2');

CREATE FUNCTION rw_view1_trig_fn()
RETURNS trigger AS
$$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE base_tbl SET b=NEW.b WHERE a=1;
    RETURN NULL;
  END IF;
  RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER rw_view1_ins_trig AFTER INSERT ON base_tbl
  FOR EACH ROW EXECUTE PROCEDURE rw_view1_trig_fn();

CREATE VIEW rw_view1 AS SELECT a AS aa, b AS bb FROM base_tbl;

INSERT INTO rw_view1 VALUES (3, 'Row 3');
select * from base_tbl;

DROP VIEW rw_view1;
DROP TRIGGER rw_view1_ins_trig on base_tbl;
DROP FUNCTION rw_view1_trig_fn();
DROP TABLE base_tbl;

-- view with ORDER BY

CREATE TABLE base_tbl (a int, b int);
INSERT INTO base_tbl VALUES (1,2), (4,5), (3,-3);

CREATE VIEW rw_view1 AS SELECT * FROM base_tbl ORDER BY a+b;

SELECT * FROM rw_view1;

INSERT INTO rw_view1 VALUES (7,-8);
SELECT * FROM rw_view1;

EXPLAIN (verbose, costs off) UPDATE rw_view1 SET b = b + 1 RETURNING *;
UPDATE rw_view1 SET b = b + 1 RETURNING *;
SELECT * FROM rw_view1;

DROP TABLE base_tbl CASCADE;

-- multiple array-column updates

CREATE TABLE base_tbl (a int, arr int[]);
INSERT INTO base_tbl VALUES (1,ARRAY[2]), (3,ARRAY[4]);

CREATE VIEW rw_view1 AS SELECT * FROM base_tbl;

UPDATE rw_view1 SET arr[1] = 42, arr[2] = 77 WHERE a = 3;

SELECT * FROM rw_view1;

DROP TABLE base_tbl CASCADE;

-- views with updatable and non-updatable columns

CREATE TABLE base_tbl(a float);
INSERT INTO base_tbl SELECT i/10.0 FROM generate_series(1,10) g(i);

CREATE VIEW rw_view1 AS
  SELECT ctid, sin(a) s, a, cos(a) c
  FROM base_tbl
  WHERE a != 0
  ORDER BY abs(a);

INSERT INTO rw_view1 VALUES (null, null, 1.1, null); -- should fail
INSERT INTO rw_view1 (s, c, a) VALUES (null, null, 1.1); -- should fail
INSERT INTO rw_view1 (a) VALUES (1.1) RETURNING a, s, c; -- OK
UPDATE rw_view1 SET s = s WHERE a = 1.1; -- should fail
UPDATE rw_view1 SET a = 1.05 WHERE a = 1.1 RETURNING s; -- OK
DELETE FROM rw_view1 WHERE a = 1.05; -- OK

CREATE VIEW rw_view2 AS
  SELECT s, c, s/c t, a base_a, ctid
  FROM rw_view1;

INSERT INTO rw_view2 VALUES (null, null, null, 1.1, null); -- should fail
INSERT INTO rw_view2(s, c, base_a) VALUES (null, null, 1.1); -- should fail
INSERT INTO rw_view2(base_a) VALUES (1.1) RETURNING t; -- OK
UPDATE rw_view2 SET s = s WHERE base_a = 1.1; -- should fail
UPDATE rw_view2 SET t = t WHERE base_a = 1.1; -- should fail
UPDATE rw_view2 SET base_a = 1.05 WHERE base_a = 1.1; -- OK
DELETE FROM rw_view2 WHERE base_a = 1.05 RETURNING base_a, s, c, t; -- OK

CREATE VIEW rw_view3 AS
  SELECT s, c, s/c t, ctid
  FROM rw_view1;

INSERT INTO rw_view3 VALUES (null, null, null, null); -- should fail
INSERT INTO rw_view3(s) VALUES (null); -- should fail
UPDATE rw_view3 SET s = s; -- should fail
DELETE FROM rw_view3 WHERE s = sin(0.1); -- should be OK
SELECT * FROM base_tbl ORDER BY a;

SELECT table_name, is_insertable_into
  FROM information_schema.tables
 WHERE table_name LIKE E'r_\\_view%'
 ORDER BY table_name;

SELECT table_name, is_updatable, is_insertable_into
  FROM information_schema.views
 WHERE table_name LIKE E'r_\\_view%'
 ORDER BY table_name;

SELECT table_name, column_name, is_updatable
  FROM information_schema.columns
 WHERE table_name LIKE E'r_\\_view%'
 ORDER BY table_name, ordinal_position;

SELECT events & 4 != 0 AS upd,
       events & 8 != 0 AS ins,
       events & 16 != 0 AS del
  FROM pg_catalog.pg_relation_is_updatable('rw_view3'::regclass, false) t(events);

DROP TABLE base_tbl CASCADE;

-- view on table with GENERATED columns

CREATE TABLE base_tbl (id int, idplus1 int GENERATED ALWAYS AS (id + 1) STORED);
CREATE VIEW rw_view1 AS SELECT * FROM base_tbl;

INSERT INTO base_tbl (id) VALUES (1);
INSERT INTO rw_view1 (id) VALUES (2);
INSERT INTO base_tbl (id, idplus1) VALUES (3, DEFAULT);
INSERT INTO rw_view1 (id, idplus1) VALUES (4, DEFAULT);
INSERT INTO base_tbl (id, idplus1) VALUES (5, 6);  -- error
INSERT INTO rw_view1 (id, idplus1) VALUES (6, 7);  -- error

SELECT * FROM base_tbl;

UPDATE base_tbl SET id = 2000 WHERE id = 2;
UPDATE rw_view1 SET id = 3000 WHERE id = 3;

SELECT * FROM base_tbl;

DROP TABLE base_tbl CASCADE;

-- simple WITH CHECK OPTION

CREATE TABLE base_tbl (a int, b int DEFAULT 10);
INSERT INTO base_tbl VALUES (1,2), (2,3), (1,-1);

CREATE VIEW rw_view1 AS SELECT * FROM base_tbl WHERE a < b
  WITH LOCAL CHECK OPTION;
\d+ rw_view1
SELECT * FROM information_schema.views WHERE table_name = 'rw_view1';

INSERT INTO rw_view1 VALUES(3,4); -- ok
INSERT INTO rw_view1 VALUES(4,3); -- should fail
INSERT INTO rw_view1 VALUES(5,null); -- should fail
UPDATE rw_view1 SET b = 5 WHERE a = 3; -- ok
UPDATE rw_view1 SET b = -5 WHERE a = 3; -- should fail
INSERT INTO rw_view1(a) VALUES (9); -- ok
INSERT INTO rw_view1(a) VALUES (10); -- should fail
SELECT * FROM base_tbl;

DROP TABLE base_tbl CASCADE;

-- WITH LOCAL/CASCADED CHECK OPTION

CREATE TABLE base_tbl (a int);

CREATE VIEW rw_view1 AS SELECT * FROM base_tbl WHERE a > 0;
CREATE VIEW rw_view2 AS SELECT * FROM rw_view1 WHERE a < 10
  WITH CHECK OPTION; -- implicitly cascaded
\d+ rw_view2
SELECT * FROM information_schema.views WHERE table_name = 'rw_view2';

INSERT INTO rw_view2 VALUES (-5); -- should fail
INSERT INTO rw_view2 VALUES (5); -- ok
INSERT INTO rw_view2 VALUES (15); -- should fail
SELECT * FROM base_tbl;

UPDATE rw_view2 SET a = a - 10; -- should fail
UPDATE rw_view2 SET a = a + 10; -- should fail

CREATE OR REPLACE VIEW rw_view2 AS SELECT * FROM rw_view1 WHERE a < 10
  WITH LOCAL CHECK OPTION;
\d+ rw_view2
SELECT * FROM information_schema.views WHERE table_name = 'rw_view2';

INSERT INTO rw_view2 VALUES (-10); -- ok, but not in view
INSERT INTO rw_view2 VALUES (20); -- should fail
SELECT * FROM base_tbl;

ALTER VIEW rw_view1 SET (check_option=here); -- invalid
ALTER VIEW rw_view1 SET (check_option=local);

INSERT INTO rw_view2 VALUES (-20); -- should fail
INSERT INTO rw_view2 VALUES (30); -- should fail

ALTER VIEW rw_view2 RESET (check_option);
\d+ rw_view2
SELECT * FROM information_schema.views WHERE table_name = 'rw_view2';
INSERT INTO rw_view2 VALUES (30); -- ok, but not in view
SELECT * FROM base_tbl;

DROP TABLE base_tbl CASCADE;

-- WITH CHECK OPTION with no local view qual

CREATE TABLE base_tbl (a int);

CREATE VIEW rw_view1 AS SELECT * FROM base_tbl WITH CHECK OPTION;
CREATE VIEW rw_view2 AS SELECT * FROM rw_view1 WHERE a > 0;
CREATE VIEW rw_view3 AS SELECT * FROM rw_view2 WITH CHECK OPTION;
SELECT * FROM information_schema.views WHERE table_name LIKE E'rw\_view_' ORDER BY table_name;

INSERT INTO rw_view1 VALUES (-1); -- ok
INSERT INTO rw_view1 VALUES (1); -- ok
INSERT INTO rw_view2 VALUES (-2); -- ok, but not in view
INSERT INTO rw_view2 VALUES (2); -- ok
INSERT INTO rw_view3 VALUES (-3); -- should fail
INSERT INTO rw_view3 VALUES (3); -- ok

DROP TABLE base_tbl CASCADE;

-- WITH CHECK OPTION with subquery

CREATE TABLE base_tbl (a int);
CREATE TABLE ref_tbl (a int PRIMARY KEY);
INSERT INTO ref_tbl SELECT * FROM generate_series(1,10);

CREATE VIEW rw_view1 AS
  SELECT * FROM base_tbl b
  WHERE EXISTS(SELECT 1 FROM ref_tbl r WHERE r.a = b.a)
  WITH CHECK OPTION;

INSERT INTO rw_view1 VALUES (5); -- ok
INSERT INTO rw_view1 VALUES (15); -- should fail

UPDATE rw_view1 SET a = a + 5; -- ok
UPDATE rw_view1 SET a = a + 5; -- should fail

EXPLAIN (costs off) INSERT INTO rw_view1 VALUES (5);
EXPLAIN (costs off) UPDATE rw_view1 SET a = a + 5;

DROP TABLE base_tbl, ref_tbl CASCADE;

-- WITH CHECK OPTION with BEFORE trigger on base table

CREATE TABLE base_tbl (a int, b int);

CREATE FUNCTION base_tbl_trig_fn()
RETURNS trigger AS
$$
BEGIN
  NEW.b := 10;
  RETURN NEW;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER base_tbl_trig BEFORE INSERT OR UPDATE ON base_tbl
  FOR EACH ROW EXECUTE PROCEDURE base_tbl_trig_fn();

CREATE VIEW rw_view1 AS SELECT * FROM base_tbl WHERE a < b WITH CHECK OPTION;

INSERT INTO rw_view1 VALUES (5,0); -- ok
INSERT INTO rw_view1 VALUES (15, 20); -- should fail
UPDATE rw_view1 SET a = 20, b = 30; -- should fail

DROP TABLE base_tbl CASCADE;
DROP FUNCTION base_tbl_trig_fn();

-- WITH LOCAL CHECK OPTION with INSTEAD OF trigger on base view

CREATE TABLE base_tbl (a int, b int);

CREATE VIEW rw_view1 AS SELECT a FROM base_tbl WHERE a < b;

CREATE FUNCTION rw_view1_trig_fn()
RETURNS trigger AS
$$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO base_tbl VALUES (NEW.a, 10);
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE base_tbl SET a=NEW.a WHERE a=OLD.a;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    DELETE FROM base_tbl WHERE a=OLD.a;
    RETURN OLD;
  END IF;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER rw_view1_trig
  INSTEAD OF INSERT OR UPDATE OR DELETE ON rw_view1
  FOR EACH ROW EXECUTE PROCEDURE rw_view1_trig_fn();

CREATE VIEW rw_view2 AS
  SELECT * FROM rw_view1 WHERE a > 0 WITH LOCAL CHECK OPTION;

INSERT INTO rw_view2 VALUES (-5); -- should fail
INSERT INTO rw_view2 VALUES (5); -- ok
INSERT INTO rw_view2 VALUES (50); -- ok, but not in view
UPDATE rw_view2 SET a = a - 10; -- should fail
SELECT * FROM base_tbl;

-- Check option won't cascade down to base view with INSTEAD OF triggers

ALTER VIEW rw_view2 SET (check_option=cascaded);
INSERT INTO rw_view2 VALUES (100); -- ok, but not in view (doesn't fail rw_view1's check)
UPDATE rw_view2 SET a = 200 WHERE a = 5; -- ok, but not in view (doesn't fail rw_view1's check)
SELECT * FROM base_tbl;

-- Neither local nor cascaded check options work with INSTEAD rules

DROP TRIGGER rw_view1_trig ON rw_view1;
CREATE RULE rw_view1_ins_rule AS ON INSERT TO rw_view1
  DO INSTEAD INSERT INTO base_tbl VALUES (NEW.a, 10);
CREATE RULE rw_view1_upd_rule AS ON UPDATE TO rw_view1
  DO INSTEAD UPDATE base_tbl SET a=NEW.a WHERE a=OLD.a;
INSERT INTO rw_view2 VALUES (-10); -- ok, but not in view (doesn't fail rw_view2's check)
INSERT INTO rw_view2 VALUES (5); -- ok
INSERT INTO rw_view2 VALUES (20); -- ok, but not in view (doesn't fail rw_view1's check)
UPDATE rw_view2 SET a = 30 WHERE a = 5; -- ok, but not in view (doesn't fail rw_view1's check)
INSERT INTO rw_view2 VALUES (5); -- ok
UPDATE rw_view2 SET a = -5 WHERE a = 5; -- ok, but not in view (doesn't fail rw_view2's check)
SELECT * FROM base_tbl;

DROP TABLE base_tbl CASCADE;
DROP FUNCTION rw_view1_trig_fn();

CREATE TABLE base_tbl (a int);
CREATE VIEW rw_view1 AS SELECT a,10 AS b FROM base_tbl;
CREATE RULE rw_view1_ins_rule AS ON INSERT TO rw_view1
  DO INSTEAD INSERT INTO base_tbl VALUES (NEW.a);
CREATE VIEW rw_view2 AS
  SELECT * FROM rw_view1 WHERE a > b WITH LOCAL CHECK OPTION;
INSERT INTO rw_view2 VALUES (2,3); -- ok, but not in view (doesn't fail rw_view2's check)
DROP TABLE base_tbl CASCADE;

-- security barrier view

CREATE TABLE base_tbl (person text, visibility text);
INSERT INTO base_tbl VALUES ('Tom', 'public'),
                            ('Dick', 'private'),
                            ('Harry', 'public');

CREATE VIEW rw_view1 AS
  SELECT person FROM base_tbl WHERE visibility = 'public';

CREATE FUNCTION snoop(anyelement)
RETURNS boolean AS
$$
BEGIN
  RAISE NOTICE 'snooped value: %', $1;
  RETURN true;
END;
$$
LANGUAGE plpgsql COST 0.000001;

SELECT * FROM rw_view1 WHERE snoop(person);
UPDATE rw_view1 SET person=person WHERE snoop(person);
DELETE FROM rw_view1 WHERE NOT snoop(person);

ALTER VIEW rw_view1 SET (security_barrier = true);

SELECT table_name, is_insertable_into
  FROM information_schema.tables
 WHERE table_name = 'rw_view1';

SELECT table_name, is_updatable, is_insertable_into
  FROM information_schema.views
 WHERE table_name = 'rw_view1';

SELECT table_name, column_name, is_updatable
  FROM information_schema.columns
 WHERE table_name = 'rw_view1'
 ORDER BY ordinal_position;

SELECT * FROM rw_view1 WHERE snoop(person);
UPDATE rw_view1 SET person=person WHERE snoop(person);
DELETE FROM rw_view1 WHERE NOT snoop(person);

EXPLAIN (costs off) SELECT * FROM rw_view1 WHERE snoop(person);
EXPLAIN (costs off) UPDATE rw_view1 SET person=person WHERE snoop(person);
EXPLAIN (costs off) DELETE FROM rw_view1 WHERE NOT snoop(person);

-- security barrier view on top of security barrier view

CREATE VIEW rw_view2 WITH (security_barrier = true) AS
  SELECT * FROM rw_view1 WHERE snoop(person);

SELECT table_name, is_insertable_into
  FROM information_schema.tables
 WHERE table_name = 'rw_view2';

SELECT table_name, is_updatable, is_insertable_into
  FROM information_schema.views
 WHERE table_name = 'rw_view2';

SELECT table_name, column_name, is_updatable
  FROM information_schema.columns
 WHERE table_name = 'rw_view2'
 ORDER BY ordinal_position;

SELECT * FROM rw_view2 WHERE snoop(person);
UPDATE rw_view2 SET person=person WHERE snoop(person);
DELETE FROM rw_view2 WHERE NOT snoop(person);

EXPLAIN (costs off) SELECT * FROM rw_view2 WHERE snoop(person);
EXPLAIN (costs off) UPDATE rw_view2 SET person=person WHERE snoop(person);
EXPLAIN (costs off) DELETE FROM rw_view2 WHERE NOT snoop(person);

DROP TABLE base_tbl CASCADE;

-- security barrier view on top of table with rules

CREATE TABLE base_tbl(id int PRIMARY KEY, data text, deleted boolean);
INSERT INTO base_tbl VALUES (1, 'Row 1', false), (2, 'Row 2', true);

CREATE RULE base_tbl_ins_rule AS ON INSERT TO base_tbl
  WHERE EXISTS (SELECT 1 FROM base_tbl t WHERE t.id = new.id)
  DO INSTEAD
    UPDATE base_tbl SET data = new.data, deleted = false WHERE id = new.id;

CREATE RULE base_tbl_del_rule AS ON DELETE TO base_tbl
  DO INSTEAD
    UPDATE base_tbl SET deleted = true WHERE id = old.id;

CREATE VIEW rw_view1 WITH (security_barrier=true) AS
  SELECT id, data FROM base_tbl WHERE NOT deleted;

SELECT * FROM rw_view1;

EXPLAIN (costs off) DELETE FROM rw_view1 WHERE id = 1 AND snoop(data);
DELETE FROM rw_view1 WHERE id = 1 AND snoop(data);

EXPLAIN (costs off) INSERT INTO rw_view1 VALUES (2, 'New row 2');
INSERT INTO rw_view1 VALUES (2, 'New row 2');

SELECT * FROM base_tbl;

DROP TABLE base_tbl CASCADE;

DROP FUNCTION snoop(anyelement);

--
-- Test CREATE OR REPLACE VIEW turning a non-updatable view into an
-- auto-updatable view and adding check options in a single step
--
CREATE TABLE t1 (a int, b text);
CREATE VIEW v1 AS SELECT null::int AS a;
CREATE OR REPLACE VIEW v1 AS SELECT * FROM t1 WHERE a > 0 WITH CHECK OPTION;

INSERT INTO v1 VALUES (1, 'ok'); -- ok
INSERT INTO v1 VALUES (-1, 'invalid'); -- should fail

DROP VIEW v1;
DROP TABLE t1;

-- Test single- and multi-row inserts with table and view defaults.
-- Table defaults should be used, unless overridden by view defaults.
create table base_tab_def (a int, b text default 'Table default',
                           c text default 'Table default', d text, e text);
create view base_tab_def_view as select * from base_tab_def;
alter view base_tab_def_view alter b set default 'View default';
alter view base_tab_def_view alter d set default 'View default';
insert into base_tab_def values (1);
insert into base_tab_def values (2), (3);
insert into base_tab_def values (4, default, default, default, default);
insert into base_tab_def values (5, default, default, default, default),
                                (6, default, default, default, default);
insert into base_tab_def_view values (11);
insert into base_tab_def_view values (12), (13);
insert into base_tab_def_view values (14, default, default, default, default);
insert into base_tab_def_view values (15, default, default, default, default),
                                     (16, default, default, default, default);
insert into base_tab_def_view values (17), (default);
select * from base_tab_def order by a;

-- Adding an INSTEAD OF trigger should cause NULLs to be inserted instead of
-- table defaults, where there are no view defaults.
create function base_tab_def_view_instrig_func() returns trigger
as
$$
begin
  insert into base_tab_def values (new.a, new.b, new.c, new.d, new.e);
  return new;
end;
$$
language plpgsql;
create trigger base_tab_def_view_instrig instead of insert on base_tab_def_view
  for each row execute procedure base_tab_def_view_instrig_func();
truncate base_tab_def;
insert into base_tab_def values (1);
insert into base_tab_def values (2), (3);
insert into base_tab_def values (4, default, default, default, default);
insert into base_tab_def values (5, default, default, default, default),
                                (6, default, default, default, default);
insert into base_tab_def_view values (11);
insert into base_tab_def_view values (12), (13);
insert into base_tab_def_view values (14, default, default, default, default);
insert into base_tab_def_view values (15, default, default, default, default),
                                     (16, default, default, default, default);
insert into base_tab_def_view values (17), (default);
select * from base_tab_def order by a;

-- Using an unconditional DO INSTEAD rule should also cause NULLs to be
-- inserted where there are no view defaults.
drop trigger base_tab_def_view_instrig on base_tab_def_view;
drop function base_tab_def_view_instrig_func;
create rule base_tab_def_view_ins_rule as on insert to base_tab_def_view
  do instead insert into base_tab_def values (new.a, new.b, new.c, new.d, new.e);
truncate base_tab_def;
insert into base_tab_def values (1);
insert into base_tab_def values (2), (3);
insert into base_tab_def values (4, default, default, default, default);
insert into base_tab_def values (5, default, default, default, default),
                                (6, default, default, default, default);
insert into base_tab_def_view values (11);
insert into base_tab_def_view values (12), (13);
insert into base_tab_def_view values (14, default, default, default, default);
insert into base_tab_def_view values (15, default, default, default, default),
                                     (16, default, default, default, default);
insert into base_tab_def_view values (17), (default);
select * from base_tab_def order by a;

-- A DO ALSO rule should cause each row to be inserted twice. The first
-- insert should behave the same as an auto-updatable view (using table
-- defaults, unless overridden by view defaults). The second insert should
-- behave the same as a rule-updatable view (inserting NULLs where there are
-- no view defaults).
drop rule base_tab_def_view_ins_rule on base_tab_def_view;
create rule base_tab_def_view_ins_rule as on insert to base_tab_def_view
  do also insert into base_tab_def values (new.a, new.b, new.c, new.d, new.e);
truncate base_tab_def;
insert into base_tab_def values (1);
insert into base_tab_def values (2), (3);
insert into base_tab_def values (4, default, default, default, default);
insert into base_tab_def values (5, default, default, default, default),
                                (6, default, default, default, default);
insert into base_tab_def_view values (11);
insert into base_tab_def_view values (12), (13);
insert into base_tab_def_view values (14, default, default, default, default);
insert into base_tab_def_view values (15, default, default, default, default),
                                     (16, default, default, default, default);
insert into base_tab_def_view values (17), (default);
select * from base_tab_def order by a, c NULLS LAST;

drop view base_tab_def_view;
drop table base_tab_def;

-- check that an auto-updatable view on a partitioned table works correctly
create table base_partition_tbl (
  num int,
  data1 text
) partition by range(num) (
  partition num1 values less than (10),
  partition num2 values less than (20),
  partition num3 values less than (30)
);
create view num1_view as select * from base_partition_tbl partition (num1);
insert into num1_view values (15, 'should fail');
insert into num1_view values (5, 'success');

drop table base_partition_tbl cascade;

-- check sublink and subquery
CREATE TABLE base_tbl1(id int PRIMARY KEY, num int);
CREATE TABLE base_tbl2(id int PRIMARY KEY, num int);
INSERT INTO base_tbl1 VALUES (1, 1), (2, 2);
INSERT INTO base_tbl2 VALUES (1, 3), (2, 4);
create view rw_view1 as select *, (select num from base_tbl2 where base_tbl2.id = base_tbl1.id limit 1) c
from base_tbl1 where exists (select * from base_tbl1 a join base_tbl2 b on a.id = b.id);
insert into rw_view1(id, num) values (3, 3);

create view rw_view2 as select *, (select num from base_tbl2 where base_tbl2.id = d.id limit 1) c
from base_tbl1 d where exists (select * from base_tbl1 a right join base_tbl2 b on a.id = b.id where b.id = d.id)
with local check option;

insert into rw_view2(id, num) values (4, 4); -- fail
insert into base_tbl2 VALUES (4, 5);
insert into rw_view2(id, num) values (4, 4);

-- merge into unsupport
merge into rw_view1 a using base_tbl2 b on (a.id = b.id)
when matched then
  update set a.num = b.num
when not matched then
  insert values (b.id, b,num);

-- upsert unsupport
INSERT INTO rw_view1 VALUES(5, 5) ON DUPLICATE KEY UPDATE num = 5;

drop table base_tbl1 cascade;
drop table base_tbl2 cascade;

CREATE TABLE tx1 (a integer);
CREATE TABLE tx2 (b integer);
CREATE TABLE tx3 (c integer);
CREATE VIEW vx1 AS SELECT a FROM tx1 WHERE EXISTS(SELECT 1 FROM tx2 JOIN tx3 ON b=c);
INSERT INTO vx1 values (1);
SELECT * FROM tx1;
SELECT * FROM vx1;

DROP VIEW vx1;
DROP TABLE tx1;
DROP TABLE tx2;
DROP TABLE tx3;

CREATE TABLE tx1 (a integer);
CREATE TABLE tx2 (b integer);
CREATE TABLE tx3 (c integer);
CREATE VIEW vx1 AS SELECT a FROM tx1 WHERE EXISTS(SELECT 1 FROM tx2 JOIN tx3 ON b=c);
INSERT INTO vx1 VALUES (1);
INSERT INTO vx1 VALUES (1);
SELECT * FROM tx1;
SELECT * FROM vx1;

DROP VIEW vx1;
DROP TABLE tx1;
DROP TABLE tx2;
DROP TABLE tx3;

CREATE TABLE tx1 (a integer, b integer);
CREATE TABLE tx2 (b integer, c integer);
CREATE TABLE tx3 (c integer, d integer);
ALTER TABLE tx1 DROP COLUMN b;
ALTER TABLE tx2 DROP COLUMN c;
ALTER TABLE tx3 DROP COLUMN d;
CREATE VIEW vx1 AS SELECT a FROM tx1 WHERE EXISTS(SELECT 1 FROM tx2 JOIN tx3 ON b=c);
INSERT INTO vx1 VALUES (1);
INSERT INTO vx1 VALUES (1);
SELECT * FROM tx1;
SELECT * FROM vx1;

DROP VIEW vx1;
DROP TABLE tx1;
DROP TABLE tx2;
DROP TABLE tx3;

create database updatable_views_db DBCOMPATIBILITY = 'B';
\c updatable_views_db

create table base_tbl1 (id int, num int);
create view rw_view1 as select * from base_tbl1 where id > 0;
create view rw_view2 as select * from rw_view1 where id < 10;

alter view rw_view2 as select * from rw_view1 where id < 10 with local check option;

insert into rw_view2 values (0); -- ok
insert into rw_view2 values (10); -- fail

alter view rw_view2 as select * from rw_view1 where id < 10 with cascaded check option;

insert into rw_view2 values (0); -- fail
insert into rw_view2 values (10); -- fail

\c regression
drop database updatable_views_db;