--Yijun Fang
--z5061743

--Q1
create type TranscriptRecord as (code char(8), term char(4), course integer, prog char(4), name text, mark integer, grade char(2), uoc integer, rank integer, totalEnrols integer );
create type TmpRecord as (code char(8), term char(4), course integer, prog char(4), name text, mark integer, grade char(2), uoc integer );

create or replace function Q1(integer) 
	returns setof TranscriptRecord as $$
declare
	record TmpRecord;
	result TranscriptRecord;
	stu_id integer;
	studentrank integer:=0;
	totalstudent integer:=0;

begin
	select s.id into stu_id
	from   Students s join People p on (s.id = p.id)
	where  p.unswid = $1;

	if (not found) then
		raise EXCEPTION 'Invalid student %',$1;
	end if;

		for record in 
			select distinct sub.code, 
				substr(sem.year::text,3,2)||lower(sem.term), 
		         c.id, prog.code, sub.name, 
		         ce.mark, ce.grade, sub.uoc

			from People p, Students s, 
				Course_enrolments ce, Courses c,
				Subjects sub, Semesters sem, 
				Program_enrolments pe, Programs prog

			where p.id = s.id 
					and ce.student = s.id and pe.student = s.id  
					and c.id = ce.course and c.subject = sub.id 
					and pe.program = prog.id and c.semester = sem.id 
					and pe.semester = sem.id and s.id = stu_id
			order by c.id

		loop			
			select cast (count(*) as integer) into totalstudent
			from Students, Course_enrolments, Courses
			where Course_enrolments.student = Students.id 
				and Courses.id = Course_enrolments.course
				and Course_enrolments.mark is not null 
				and Courses.id = record.course;


			if (record.mark is null 
				and record.grade not in ('SY','PT','PC','PS','CR','DN','HD','A','B','C')) then
					studentrank:=null;

			else
				select _srank into studentrank 
				from(
					select (rank() OVER (PARTITION BY ccourseid ORDER BY cmark DESC)) as _srank, 
							cstudentid as _sid, cmark as _smark 
					from(
						select cous.id as ccourseid, stu.id as cstudentid, 
							cs_enrl.mark as cmark
						from Students stu, Course_enrolments cs_enrl, Courses cous
						where cs_enrl.student = stu.id 
						 	and cous.id = cs_enrl.course
							and cs_enrl.mark is not null 
							and cous.id = record.course 
						)as tmp 
					)as ranktable 
				where ranktable._sid = stu_id; 

			end if;

			if (record.mark is not null and 
				record.grade not in ('SY','PT','PC','PS','CR','DN','HD','A','B','C')) then
				
				record:=(record.code, record.term, record.course, 
					record.prog, record.name, record.mark, record.grade, 0 );
			end if;

			result:=(record.code, record.term, record.course, 
				record.prog, record.name, record.mark, record.grade, 
				record.uoc, studentrank, totalstudent);

			return next result;

		end loop;
end;
$$ language plpgsql;

--Q2

create type MatchingRecord as ("table" text, "column" text, nexamples integer );

create or replace function Q2("table" text, pattern text) 
	returns setof MatchingRecord as $$

declare
	rec MatchingRecord;
	checkPattern text := pattern;
	tableName text :="table" ;
	columnName text;
	num integer:=0;

begin

	for columnName in
		select column_name
		from INFORMATION_SCHEMA.COLUMNS 
		where table_name = tableName
			and (data_type like '%character%'
				or data_type like 'text')

	LOOP	
		num:=0;

		EXECUTE 'select count('||columnName||') 
				from '|| tableName ||' 
				where '||columnName||'~'''||checkPattern||'''' 
		into num;
		
		if(num > 0)then
			rec:=(tableName, columnName, num);
			
			return next rec;
		end if;
	
	end LOOP;
end; 
$$ language plpgsql;



create type EmploymentRecord as (unswid integer, name text, roles text );
create type StaffRecord as (unswid integer, name text, sortname text, roles text, startDate text, endDate text );
	
create or replace view staffnrole(orgID, staffUNSWID, startDate, endDate, 
	stuffName, stuffSortName,staffRole, staffRoleName, orgName)as

	select o.id, p.unswid, a.starting, a.ending, 
		p.name,p.sortname,a.role, s.name, o.name

	from Affiliations a 
		left outer join People p on (a.staff = p.id) 
		left outer join OrgUnits o on(a.orgUnit = o.id)  
		left outer join Staff_roles s on(a.role =s.id) 
;

create or replace function findOrg(integer) 
	returns setof StaffRecord as $$

declare
	record StaffRecord;
	childLevel integer:=0;
	checkStaff integer:=0;
	start date;
	endaday date;
	currperson integer:=0;

begin

	for childLevel in 
		select member 
		from OrgUnit_groups 
		where owner = $1

	loop
		for checkstaff in
			select distinct sr.staffUNSWID		
			from staffnrole sr				
			where sr.orgID = childLevel 
				and sr.endDate is not null

		loop
			select sr.startDate into start
			from staffnrole sr				
			where sr.staffUNSWID = checkstaff 
				and sr.endDate is null
				and (sr.orgID = $1 
					or sr.orgID in (
					select member from OrgUnit_groups where owner = $1));

			select sr.endDate into endaday
			from staffnrole sr				
			where sr.staffUNSWID = checkstaff 
				and sr.endDate is not null
				and (sr.orgID = $1 
					or sr.orgID in (
					select member from OrgUnit_groups where owner = $1));

			if(endaday <= start)then
				for record in 

					select sr.staffUNSWID, sr.stuffName,sr.stuffSortName, 
							sr.staffRoleName||', '||sr.orgName, 
							sr.startDate, sr.endDate
					from staffnrole sr				
					where sr.staffUNSWID = checkstaff 

				loop

					if(record.endDate is null)then 	
						record.endDate:='';							
					end if;

					return next record;
				end loop;

			end if;
		end loop;
end loop;

end; 
$$ language plpgsql;


create or replace function Q3(integer)  
	returns setof EmploymentRecord as $$

declare
	rec EmploymentRecord;
	result EmploymentRecord;
	roletext text;
	newline text:= E'\n';

begin
	result:=(null,null,null);

	for rec in
	
		select o.unswid, o.name, 
				o.roles||' ('||o.startDate||'..'||o.endDate|| ')'||newline
		from findOrg($1) o
		order by o.sortname, o.startDate

	loop

		if(result.unswid <> rec.unswid  and result.unswid is not null)then
			 return next result;
		end if;


		if(result.unswid <> rec.unswid or result.unswid is null) then
			result := rec;

		elsif ( result.unswid = rec.unswid and result.roles <> rec.roles)then 

			roletext:=result.roles || rec.roles;
			result:=(result.unswid, result.name,roletext); 

		end if;

	end loop;
	return next result;

end;
$$ language plpgsql;


