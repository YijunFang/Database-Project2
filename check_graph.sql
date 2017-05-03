-- COMP3311 16s1 Proj 2: Triangle Listing
--
-- check.sql ... checking functions
--
--
-- Helper functions
--

create or replace function proj2_table_exists(tname text) returns boolean
as $$
declare
        _check integer := 0;
begin
        select count(*) into _check from pg_class
        where relname=tname and relkind='r';
        return (_check = 1);
end;
$$ language plpgsql;

create or replace function proj2_view_exists(tname text) returns boolean
as $$
declare
        _check integer := 0;
begin
        select count(*) into _check from pg_class
        where relname=tname and relkind='v';
        return (_check = 1);
end;
$$ language plpgsql;

create or replace function proj2_function_exists(tname text) returns boolean
as $$
declare
	_check integer := 0;
begin
	select count(*) into _check from pg_proc
	where proname=tname;
	return (_check > 0);
end;
$$ language plpgsql;



drop type if exists TestingResult cascade;
create type TestingResult as (dataset text, test text, result text);

create or replace function check_all() returns setof TestingResult
as $$
declare
	i int;
	tableQ text;
	result text;
	out TestingResult;
	tests text[] := array['triangle_naive', 'triangle_in_order'];
	datasets text[] := array['dataset0'];
begin
	for i in array_lower(datasets,1) .. array_upper(datasets,1)
    loop
    	for j in array_lower(tests,1) .. array_upper(tests,1)
		loop
			result := check_res(tests[j], datasets[i]);
			out := (datasets[i], tests[j], result);
			return next out;
		end loop;
	end loop;
end;
$$ language plpgsql;

create or replace function check_res(_name text, _dataset text) returns text
	as $$
	declare
		res integer;
		query integer;
	begin
		if (not proj2_function_exists(_name)) then
			return 'No '||_name||' function; did it load correctly?';
		end if;

		res := tri_expected(_dataset);
		if(res = -1) then
			return 'Wrong dataset specified.';
		else
			if(_name = 'triangle_naive') then
				query := triangle_naive(_dataset);
			else
				query := triangle_in_order(_dataset);
			end if;
		end if;
		if(query > res) then
			return 'too many result tuples';
		elsif(query < res) then
			return 'missing result tuples';
		else
			return 'correct';
		end if;
	end;
	$$ language plpgsql;


create or replace function tri_expected(_dataset text) returns integer
	as $$
	begin
		if(_dataset = 'dataset0') then
			return 53265;
		else
			return -1;
		end if;
	end;
	$$ language plpgsql;

