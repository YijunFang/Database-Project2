--Yijun Fang
--z5061743

create type NodeType as(v1 integer, v2 integer, v3 integer);
create type EdgeDegree as (v1 integer, v2 integer, v1deg integer, v2deg integer);
create type TriangleDegree as (v1 integer, v2 integer, v3 integer, v1deg integer, v2deg integer, v3deg integer);

create or replace function formTriangleNaive(dataset text) 
	returns setof NodeType as $$

begin
	EXECUTE
		'create or replace view WedgeNodeNaive(v1, v2, v3) as
		select distinct E1.v1, E1.v2, E2.v2
		from '||quote_ident('tbl_'||dataset)||' E1 
			inner join '||quote_ident('tbl_'||dataset)||' E2 on (E1.v1 = E2.v1)
		where E1.v2 < E2.v2';

	return QUERY
	EXECUTE
		'select distinct W.v1, W.v2, W.v3 
		from WedgeNodeNaive W 
			inner join '||quote_ident('tbl_'||dataset)||' E on (W.v2 = E.v1 and W.V3 = E.v2)
		where W.v2 < W.v3 
		order by W.v1, W.v2, W.v3'; 
end;
$$ language plpgsql;


--Q1 Entry
create or replace function triangle_naive(dataset text)
	returns integer as $$
declare
	num integer:=0;

begin
	select cast(count(*) as integer) into num
	from formTriangleNaive($1);
	return num;
end;
$$ language plpgsql;




-------------------Q2 below--------------------------------------
create type degreeID as (id integer, degree integer);

create or replace function vertexDegree(dataset text) 
	returns setof degreeID	as $$

begin
	return QUERY
	EXECUTE
		'select tbl.id, cast(sum(tbl.degree) as integer)
		from(
			select v1 as id, cast(count(*) as integer) as degree
			from '||quote_ident('tbl_'||dataset)||'
			group by v1 
			
			union
			
			select v2 as id, cast(count(*) as integer) as degree
			from '||quote_ident('tbl_'||dataset)||'
			group by v2
		) as tbl
		group by tbl.id
		order by tbl.id';
end;
$$ language plpgsql;


-- sort the list of edge with deg(v1)<deg(v2) 
	--or deg(v1)=deg(v2) and id(v1)<id(v2)
create or replace function attachEdge(dataset text) returns 
	setof EdgeDegree as $$
declare
	link EdgeDegree;

begin
	for link in 

	EXECUTE
		'select E.v1, E.v2, v1deg.degree, v2deg.degree
		from '||quote_ident('tbl_'||dataset)||' E, 
			vertexDegree('''||dataset||''') v1deg, 
			vertexDegree('''||dataset||''') v2deg
		where E.v1 = v1deg.id and E.v2 = v2deg.id 
		order by v1deg.degree'

	loop
		if (link.v1deg > link.v2deg)then
			link:=(link.v2, link.v1, link.v2deg, link.v1deg);
		end if;

		return next link;
	end loop;

end;
$$ language plpgsql;


create or replace function formWedgeOrder(dataset text) 
	returns setof TriangleDegree as $$

begin
	return QUERY
	Execute
		'select distinct E1.v1, E1.v2, E2.v2, E1.v1deg, E1.v2deg, E2.v2deg
		
		from attachEdge('''||dataset||''') E1 
			inner join attachEdge('''||dataset||''') E2 on (E1.v1 = E2.v1)
		
		where E1.v2 <> E2.v2 
			and (( E1.v2deg < E2.v2deg ) 
				or (E1.v2deg = E2.v2deg and E1.v2 < E2.v2))
		
		group by E1.v1, E1.v2, E2.v2, E1.v1deg, E1.v2deg, E2.v2deg
		order by E1.v1deg, E1.v2deg, E2.v2deg';

end;
$$ language plpgsql;



create or replace function formTriangleOrder(dataset text) 
	returns setof TriangleDegree as $$

begin
	return QUERY
	Execute
		'select distinct W.v1, W.v2, W.V3, W.v1deg, W.v2deg, W.v3deg
		from formWedgeOrder('''||dataset||''') W 
			inner join attachEdge('''||dataset||''') E1 on (W.v1 = E1.v1 and W.v2 = E1.v2)
			inner join attachEdge('''||dataset||''') E2 on (W.v1 = E2.v1 and W.v3 = E2.v2)
			inner join attachEdge('''||dataset||''') E3 on (W.v2 = E3.v1 and W.v3 = E3.v2)
		order by W.v1, W.v2, W.V3 ';
end;
$$ language plpgsql;


--Q2 entry here
 create or replace function triangle_in_order(dataset text) 
 	returns integer as $$
declare
	num integer:=0;

begin
	select cast(count(*) as integer) into num
	from formTriangleOrder($1);
	return num;
end;
$$ language plpgsql;



--ZHONG YU ZUO WAN LE!!! GAND DONG !!!! 
--ZHE ME NAN !!! ZHE ME SHAO FEN!!!  QIU MAN FEN !!!! 