--
-- check.sql ... checking functions
--
--

--
-- Helper functions
--

create or replace function
	proj2_table_exists(tname text) returns boolean
as $$
declare
	_check integer := 0;
begin
	select count(*) into _check from pg_class
	where relname=tname and relkind='r';
	return (_check = 1);
end;
$$ language plpgsql;

create or replace function
	proj2_view_exists(tname text) returns boolean
as $$
declare
	_check integer := 0;
begin
	select count(*) into _check from pg_class
	where relname=tname and relkind='v';
	return (_check = 1);
end;
$$ language plpgsql;

create or replace function
	proj2_function_exists(tname text) returns boolean
as $$
declare
	_check integer := 0;
begin
	select count(*) into _check from pg_proc
	where proname=tname;
	return (_check > 0);
end;
$$ language plpgsql;

-- proj2_check_result:
-- * determines appropriate message, based on count of
--   excess and missing tuples in user output vs expected output

create or replace function
	proj2_check_result(nexcess integer, nmissing integer) returns text
as $$
begin
	if (nexcess = 0 and nmissing = 0) then
		return 'correct';
	elsif (nexcess > 0 and nmissing = 0) then
		return 'too many result tuples';
	elsif (nexcess = 0 and nmissing > 0) then
		return 'missing result tuples';
	elsif (nexcess > 0 and nmissing > 0) then
		return 'incorrect result tuples';
	end if;
end;
$$ language plpgsql;

-- proj2_check:
-- * compares output of user view/function against expected output
-- * returns string (text message) containing analysis of results

create or replace function
	proj2_check(_type text, _name text, _res text, _query text) returns text
as $$
declare
	nexcess integer;
	nmissing integer;
	excessQ text;
	missingQ text;
begin
	if (_type = 'view' and not proj2_view_exists(_name)) then
		return 'No '||_name||' view; did it load correctly?';
	elsif (_type = 'function' and not proj2_function_exists(_name)) then
		return 'No '||_name||' function; did it load correctly?';
	elsif (not proj2_table_exists(_res)) then
		return _res||': No expected results!';
	else
		excessQ := 'select count(*) '||
			   'from (('||_query||') except '||
			   '(select * from '||_res||')) as X';
		-- raise notice 'Q: %',excessQ;
		execute excessQ into nexcess;
		missingQ := 'select count(*) '||
			    'from ((select * from '||_res||') '||
			    'except ('||_query||')) as X';
		-- raise notice 'Q: %',missingQ;
		execute missingQ into nmissing;
		return proj2_check_result(nexcess,nmissing);
	end if;
	return '???';
end;
$$ language plpgsql;

-- proj2_rescheck:
-- * compares output of user function against expected result
-- * returns string (text message) containing analysis of results

create or replace function
	proj2_rescheck(_type text, _name text, _res text, _query text) returns text
as $$
declare
	_sql text;
	_chk boolean;
begin
	if (_type = 'function' and not proj2_function_exists(_name)) then
		return 'No '||_name||' function; did it load correctly?';
	elsif (_res is null) then
		_sql := 'select ('||_query||') is null';
		-- raise notice 'SQL: %',_sql;
		execute _sql into _chk;
		-- raise notice 'CHK: %',_chk;
	else
		_sql := 'select ('||_query||') = '||quote_literal(_res);
		-- raise notice 'SQL: %',_sql;
		execute _sql into _chk;
		-- raise notice 'CHK: %',_chk;
	end if;
	if (_chk) then
		return 'correct';
	else
		return 'incorrect result';
	end if;
end;
$$ language plpgsql;

-- check_all:
-- * run all of the checks and return a table of results

drop type if exists TestingResult cascade;
create type TestingResult as (test text, result text);

create or replace function
	check_all() returns setof TestingResult
as $$
declare
	i int;
	testQ text;
	result text;
	out TestingResult;
	tests text[] := array[
				'q1', 'q2', 'q3'
				];
begin
	for i in array_lower(tests,1) .. array_upper(tests,1)
	loop
		testQ := 'select check_'||tests[i]||'()';
		execute testQ into result;
		out := (tests[i],result);
		return next out;
	end loop;
	return;
end;
$$ language plpgsql;


--
-- Check functions for specific test-cases in Project 2
--


create or replace function check_q1() returns text
as $chk$
select proj2_check('function','q1','q1_expected',
                   $$select * from q1(2237675)$$)
$chk$ language sql;

create or replace function check_q2() returns text
as $chk$
select proj2_check('function','q2','q2_expected',
                   $$select * from q2('subjects', 'COMP\d\d\d')$$)
$chk$ language sql;

create or replace function check_q3() returns text
as $chk$
select proj2_check('function','q3','q3_expected',
                   $$select * from q3(661)$$)
$chk$ language sql;

--
-- Tables of expected results for test cases
--

drop table if exists q1_expected;
create table q1_expected (
    code character(8),
    term character(4),
    course integer,
    prog character(4),
    name text,
    mark integer,
    grade character(2),
    uoc integer,
    rank integer,
    totalEnrols integer
);

drop table if exists q2_expected;
create table q2_expected (
    	"table" text, 
	"column" text, 
	nexamples integer
);

drop table if exists q3_expected;
create table q3_expected (
    	unswid integer, 
	name text, 
	roles text
);


COPY q1_expected (code, term, course, prog, name, mark, grade, uoc, rank, totalEnrols) FROM stdin;
GBAT9101	06s2	23343	8616	Project Management	80	DN	6	5	19
GBAT9106	07s1	27143	8616	Information Systems Mgt	73	CR	6	5	9
GBAT9120	07s1	27147	8616	Accounting: A User Perspective	85	HD	6	1	9
GBAT9117	07s2	30320	8616	E-Business Strategy & Mgmnt	71	CR	6	5	13
GBAT9115	08s1	34056	8616	IT in Business	62	PS	6	25	27
GBAT9130	08s1	34063	8616	Enterprise Risk Management	86	HD	6	3	14
GBAT9127	08s2	37459	8616	Supply Chain Management	36	FL	0	11	11
GBAT9123	09s2	44435	8616	Fundamentals Corporate Finance	88	HD	6	1	30
GBAT9119	10x1	46854	8616	Managing for Org Sust	45	FL	0	13	13
GBAT9126	11s1	55267	8616	Develop New Products &Services	40	FL	0	22	22
GBAT9127	11s2	58482	8616	Supply Chain Management	\N	NC	6	\N	20
GBAT9129	12s1	62192	8616	Managing Org Resources	31	FL	0	18	18
\.

COPY q2_expected ("table", "column", nexamples) FROM stdin;
subjects	code	265
subjects	syllabus	25
subjects	_excluded	49
subjects	_equivalent	58
subjects	_prereq	110
\.

COPY q3_expected (unswid, name, roles) FROM stdin;
3140956	Thomas Loveday	Senior Lecturer, Architecture Program (2011-09-05..2011-09-05)\nSenior Lecturer, Interior Architecture Program (2011-11-25..)\n
9226425	Stephen Ward	Program Head, Industrial Design Program (2001-01-01..2011-09-27)\nLecturer, Industrial Design Program (2011-09-27..)\n
\.































