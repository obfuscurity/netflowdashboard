--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

CREATE ROLE nfdb_admin LOGIN
  ENCRYPTED PASSWORD 'md536a692274b783e08ddcf7ecd8b82028a'
  NOSUPERUSER NOINHERIT CREATEDB NOCREATEROLE;

CREATE ROLE nfdb_user LOGIN
  ENCRYPTED PASSWORD 'md5a75a35cd1b3e9520486452ab626255a3'
  NOSUPERUSER NOINHERIT NOCREATEDB NOCREATEROLE;
ALTER ROLE nfdb_user SET constraint_exclusion=on;

--
-- Name: nfdb; Type: DATABASE; Schema: -; Owner: nfdb_admin
--

CREATE DATABASE nfdb WITH TEMPLATE = template0 ENCODING = 'UTF8';


ALTER DATABASE nfdb OWNER TO nfdb_admin;

\connect nfdb nfdb_admin

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: nfdb; Type: COMMENT; Schema: -; Owner: nfdb_admin
--

COMMENT ON DATABASE nfdb IS 'NetFlow Dashboard';


--
-- Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: nfdb_admin
--

CREATE PROCEDURAL LANGUAGE plpgsql;


ALTER PROCEDURAL LANGUAGE plpgsql OWNER TO nfdb_admin;

SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: devices; Type: TABLE; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE TABLE devices (
    device_addr inet DEFAULT '0.0.0.0'::inet NOT NULL,
    name character varying(50),
    description character varying(50)
);


ALTER TABLE public.devices OWNER TO nfdb_admin;

--
-- Name: flows_template; Type: TABLE; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE TABLE flows_template (
    protocol smallint DEFAULT 0 NOT NULL,
    flow_timestamp timestamp with time zone DEFAULT now() NOT NULL,
    time_nanosec integer DEFAULT 0 NOT NULL,
    recv_secs integer DEFAULT 0 NOT NULL,
    sys_uptime_ms bigint DEFAULT 0 NOT NULL,
    src_addr inet DEFAULT '0.0.0.0'::inet NOT NULL,
    src_mask smallint DEFAULT 0 NOT NULL,
    src_port integer DEFAULT 0 NOT NULL,
    src_addr_af smallint DEFAULT 0 NOT NULL,
    src_as smallint DEFAULT 0 NOT NULL,
    dst_addr inet DEFAULT '0.0.0.0'::inet NOT NULL,
    dst_mask smallint DEFAULT 0 NOT NULL,
    dst_port integer DEFAULT 0 NOT NULL,
    dst_addr_af smallint DEFAULT 0 NOT NULL,
    dst_as smallint DEFAULT 0 NOT NULL,
    gateway_addr inet DEFAULT '0.0.0.0'::inet NOT NULL,
    gateway_addr_af smallint DEFAULT 0 NOT NULL,
    agent_addr inet DEFAULT '0.0.0.0'::inet NOT NULL,
    agent_addr_af smallint DEFAULT 0 NOT NULL,
    if_index_in smallint DEFAULT 0 NOT NULL,
    if_index_out smallint DEFAULT 0 NOT NULL,
    flow_start bigint DEFAULT 0 NOT NULL,
    flow_finish bigint DEFAULT 0 NOT NULL,
    flow_octets bigint DEFAULT 0 NOT NULL,
    flow_packets integer DEFAULT 0 NOT NULL,
    tcp_flags smallint DEFAULT 0 NOT NULL,
    tos smallint DEFAULT 0 NOT NULL,
    crc bigint DEFAULT 0 NOT NULL,
    ffields integer DEFAULT 0 NOT NULL,
    netflow_version smallint DEFAULT 0 NOT NULL,
    engine_id smallint DEFAULT 0 NOT NULL,
    engine_type smallint DEFAULT 0 NOT NULL
);


ALTER TABLE public.flows_template OWNER TO nfdb_admin;

--
-- Name: groups; Type: TABLE; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE TABLE groups (
    id smallint NOT NULL,
    name character varying(20) NOT NULL,
    description character varying(50)
);


ALTER TABLE public.groups OWNER TO nfdb_admin;

--
-- Name: groups_members; Type: TABLE; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE TABLE groups_members (
    device_addr inet DEFAULT '0.0.0.0'::inet NOT NULL,
    group_id smallint DEFAULT 0 NOT NULL
);


ALTER TABLE public.groups_members OWNER TO nfdb_admin;

--
-- Name: interfaces; Type: TABLE; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE TABLE interfaces (
    device_addr inet DEFAULT '0.0.0.0'::inet NOT NULL,
    id smallint DEFAULT 0 NOT NULL,
    name character varying(20),
    speed integer DEFAULT 1073741824
);


ALTER TABLE public.interfaces OWNER TO nfdb_admin;

--
-- Name: protocols_custom; Type: TABLE; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE TABLE protocols_custom (
    name character varying(20) NOT NULL,
    number smallint DEFAULT 0 NOT NULL
);


ALTER TABLE public.protocols_custom OWNER TO nfdb_admin;

--
-- Name: protocols_default; Type: TABLE; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE TABLE protocols_default (
    name character varying(20) NOT NULL,
    number smallint DEFAULT 0 NOT NULL
);


ALTER TABLE public.protocols_default OWNER TO nfdb_admin;

--
-- Name: services_custom; Type: TABLE; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE TABLE services_custom (
    name character varying(20) NOT NULL,
    port integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.services_custom OWNER TO nfdb_admin;

--
-- Name: services_default; Type: TABLE; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE TABLE services_default (
    name character varying(20) NOT NULL,
    port integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.services_default OWNER TO nfdb_admin;

--
-- Name: create_day_flow_partitions(text); Type: FUNCTION; Schema: public; Owner: nfdb_admin
--

CREATE FUNCTION create_day_flow_partitions(text) RETURNS void
    AS $$
DECLARE
	date text := $1;
	tablename text;
BEGIN
	FOR hour IN 0..23 LOOP
		tablename := 'flows_' || date || to_char(hour, 'FM00');
		EXECUTE 'DROP TABLE IF EXISTS '
			|| tablename
			|| ';';
		EXECUTE 'CREATE TABLE ' 
			|| tablename 
			|| ' ( CHECK ( flow_timestamp >= TIMESTAMP WITH TIME ZONE '''
			|| date || ' ' || to_char(hour, 'FM00') || ':00:00'''
			|| ' AND flow_timestamp < TIMESTAMP WITH TIME ZONE '''
			|| date || ' ' || to_char((hour + 1), 'FM00') || ':00:00'''
			|| ' ) ) INHERITS (flows_template);';
		EXECUTE 'GRANT SELECT,INSERT,UPDATE ON TABLE ' 
			|| tablename 
			|| ' TO nfdb_user;';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_agent_addr ON ' 
			|| tablename
			|| ' (agent_addr);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_src_addr ON ' 
			|| tablename
			|| ' (src_addr);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_src_port ON ' 
			|| tablename
			|| ' (src_port);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_dst_addr ON ' 
			|| tablename
			|| ' (dst_addr);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_dst_port ON ' 
			|| tablename
			|| ' (dst_port);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_if_index_in ON ' 
			|| tablename
			|| ' (if_index_in);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_if_index_out ON ' 
			|| tablename
			|| ' (if_index_out);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_timestamp ON ' 
			|| tablename
			|| ' (flow_timestamp);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_ifindexin_timestamp_agent ON ' 
			|| tablename
			|| ' (if_index_in, flow_timestamp, agent_addr);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_srcport_agent_timestamp_ifindexin ON ' 
			|| tablename
			|| ' (src_port, agent_addr, flow_timestamp, if_index_in);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_dstport_agent_timestamp_ifindexin ON ' 
			|| tablename
			|| ' (dst_port, agent_addr, flow_timestamp, if_index_in);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_srcaddr_agent_timestamp_ifindexin ON ' 
			|| tablename
			|| ' (src_addr, agent_addr, flow_timestamp, if_index_in);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_dstaddr_agent_timestamp_ifindexin ON ' 
			|| tablename
			|| ' (dst_addr, agent_addr, flow_timestamp, if_index_in);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_proto_agent_timestamp_srcport_ifindexin ON ' 
			|| tablename
			|| ' (protocol, agent_addr, flow_timestamp, src_port, if_index_in);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_proto_agent_timestamp_dstport_ifindexin ON ' 
			|| tablename
			|| ' (protocol, agent_addr, flow_timestamp, dst_port, if_index_in);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_srcaddrport_dstaddrport ON ' 
			|| tablename
			|| ' (src_addr, src_port, dst_addr, dst_port);';
		EXECUTE 'CREATE UNIQUE INDEX index_'
			|| tablename
			|| '_flows_unique ON '
			|| tablename
			|| ' ((case when src_addr > dst_addr then src_addr||''@@''||dst_addr '
			|| ' ELSE dst_addr||''@@''||src_addr END), (CASE WHEN src_port > dst_port '
			|| ' THEN src_port||''@@''||dst_port ELSE dst_port||''@@''||src_port END), '
			|| 'flow_start, flow_finish, agent_addr);';
	END LOOP;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.create_day_flow_partitions(text) OWNER TO nfdb_admin;

--
-- Name: create_nextday_flow_partitions(); Type: FUNCTION; Schema: public; Owner: nfdb_admin
--

CREATE FUNCTION create_nextday_flow_partitions() RETURNS void
    AS $$
DECLARE
	date text := regexp_replace(to_date((current_date + interval '1 day')::text, 'YYYY MM DD')::text, '-', '', 'g');
	tablename text;
BEGIN
	FOR hour IN 0..23 LOOP
		tablename := 'flows_' || date || to_char(hour, 'FM00');
		EXECUTE 'DROP TABLE IF EXISTS '
			|| tablename
			|| ';';
		EXECUTE 'CREATE TABLE ' 
			|| tablename 
			|| ' ( CHECK ( flow_timestamp >= TIMESTAMP WITH TIME ZONE '''
			|| date || ' ' || to_char(hour, 'FM00') || ':00:00'''
			|| ' AND flow_timestamp < TIMESTAMP WITH TIME ZONE '''
			|| date || ' ' || to_char((hour + 1), 'FM00') || ':00:00'''
			|| ' ) ) INHERITS (flows_template);';
		EXECUTE 'GRANT SELECT,INSERT,UPDATE ON TABLE ' 
			|| tablename 
			|| ' TO nfdb_user;';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_agent_addr ON ' 
			|| tablename
			|| ' (agent_addr);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_src_addr ON ' 
			|| tablename
			|| ' (src_addr);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_src_port ON ' 
			|| tablename
			|| ' (src_port);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_dst_addr ON ' 
			|| tablename
			|| ' (dst_addr);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_dst_port ON ' 
			|| tablename
			|| ' (dst_port);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_if_index_in ON ' 
			|| tablename
			|| ' (if_index_in);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_if_index_out ON ' 
			|| tablename
			|| ' (if_index_out);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_timestamp ON ' 
			|| tablename
			|| ' (flow_timestamp);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_ifindexin_timestamp_agent ON ' 
			|| tablename
			|| ' (if_index_in, flow_timestamp, agent_addr);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_srcport_agent_timestamp_ifindexin ON ' 
			|| tablename
			|| ' (src_port, agent_addr, flow_timestamp, if_index_in);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_dstport_agent_timestamp_ifindexin ON ' 
			|| tablename
			|| ' (dst_port, agent_addr, flow_timestamp, if_index_in);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_srcaddr_agent_timestamp_ifindexin ON ' 
			|| tablename
			|| ' (src_addr, agent_addr, flow_timestamp, if_index_in);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_dstaddr_agent_timestamp_ifindexin ON ' 
			|| tablename
			|| ' (dst_addr, agent_addr, flow_timestamp, if_index_in);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_proto_agent_timestamp_srcport_ifindexin ON ' 
			|| tablename
			|| ' (protocol, agent_addr, flow_timestamp, src_port, if_index_in);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_proto_agent_timestamp_dstport_ifindexin ON ' 
			|| tablename
			|| ' (protocol, agent_addr, flow_timestamp, dst_port, if_index_in);';
		EXECUTE 'CREATE INDEX index_' 
			|| tablename 
			|| '_srcaddrport_dstaddrport ON ' 
			|| tablename
			|| ' (src_addr, src_port, dst_addr, dst_port);';
		EXECUTE 'CREATE UNIQUE INDEX index_'
			|| tablename
			|| '_flows_unique ON '
			|| tablename
			|| ' ((case when src_addr > dst_addr then src_addr||''@@''||dst_addr '
			|| ' ELSE dst_addr||''@@''||src_addr END), (CASE WHEN src_port > dst_port '
			|| ' THEN src_port||''@@''||dst_port ELSE dst_port||''@@''||src_port END), '
			|| 'flow_start, flow_finish, agent_addr);';
	END LOOP;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.create_nextday_flow_partitions() OWNER TO nfdb_admin;

--
-- Name: rebuild_flows_insert_trigger(); Type: FUNCTION; Schema: public; Owner: nfdb_admin
--

CREATE FUNCTION rebuild_flows_insert_trigger() RETURNS void
    AS $$
DECLARE
	date timestamp := date_trunc('day', now());
	create_cmd text;
BEGIN
	create_cmd := 'CREATE OR REPLACE FUNCTION flows_insert_trigger() '
		|| 'RETURNS TRIGGER AS $PROC$ '
		|| 'BEGIN '
		|| 'IF ( NEW.flow_timestamp >= TIMESTAMP WITH TIME ZONE '''
		|| date
		|| ''' AND NEW.flow_timestamp < TIMESTAMP WITH TIME ZONE '''
		|| date + interval '1 hour'
		|| ''' ) THEN INSERT INTO flows_'
		|| to_char(date, 'yyyymmddhh24')
		|| ' VALUES (NEW.*);';
	FOR time IN 1..46 LOOP
		create_cmd := create_cmd 
			|| 'ELSIF ( NEW.flow_timestamp >= TIMESTAMP WITH TIME ZONE '''
			|| date + time * interval '1 hour'
			|| ''' AND NEW.flow_timestamp < TIMESTAMP WITH TIME ZONE '''
			|| date + (time + 1) * interval '1 hour'
			|| ''' ) THEN INSERT INTO flows_'
			|| to_char(date + time * interval '1 hours', 'yyyymmddhh24')
			|| ' VALUES (NEW.*);';
	END LOOP;
	create_cmd := create_cmd 
		|| 'ELSIF ( NEW.flow_timestamp >= TIMESTAMP WITH TIME ZONE '''
		|| date + interval '47 hours'
		|| ''' AND NEW.flow_timestamp < TIMESTAMP WITH TIME ZONE '''
		|| date + interval '48 hours'
		|| ''' ) THEN INSERT INTO flows_'
		|| to_char(date + interval '47 hours', 'yyyymmddhh24')
		|| ' VALUES (NEW.*);'
		|| 'ELSE RAISE EXCEPTION '
		|| '''Date out of range.  Fix flows_insert_trigger() function.'';'
		|| 'END IF;'
		|| 'RETURN NULL;'
		|| 'END;'
		|| '$PROC$ LANGUAGE plpgsql;';
	EXECUTE create_cmd;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.rebuild_flows_insert_trigger() OWNER TO nfdb_admin;

--
-- Name: drop_day_flow_partitions(integer); Type: FUNCTION; Schema: public; Owner: nfdb_admin
--

CREATE OR REPLACE FUNCTION drop_day_flow_partitions(integer) RETURNS void
	AS $$
DECLARE
		num_days_ago integer := $1;
		date text := regexp_replace(to_date((current_date - num_days_ago * interval '1 day')::text, 'YYYY MM DD')::text, '-', '', 'g');
		tablename text;
BEGIN
		FOR hour IN 0..23 LOOP
				tablename := 'flows_' || date || to_char(hour, 'FM00');
				EXECUTE 'DROP TABLE IF EXISTS ' || tablename || ';';
		END LOOP;
END;
$$ LANGUAGE plpgsql;


ALTER FUNCTION public.drop_day_flow_partitions(integer) OWNER TO nfdb_admin;

--
-- Create initial partitions and flows_insert_trigger()
--

SELECT create_day_flow_partitions(regexp_replace(to_date(current_date::text, 'YYYY MM DD')::text, '-', '', 'g'));
SELECT rebuild_flows_insert_trigger();

--
-- Name: groups_id_seq; Type: SEQUENCE; Schema: public; Owner: nfdb_admin
--

CREATE SEQUENCE groups_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.groups_id_seq OWNER TO nfdb_admin;

--
-- Name: groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nfdb_admin
--

ALTER SEQUENCE groups_id_seq OWNED BY groups.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: nfdb_admin
--

ALTER TABLE groups ALTER COLUMN id SET DEFAULT nextval('groups_id_seq'::regclass);


--
-- Name: groups_pkey; Type: CONSTRAINT; Schema: public; Owner: nfdb_admin; Tablespace: 
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: index_devices_device_addr; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_devices_device_addr ON devices USING btree (device_addr);


--
-- Name: index_flows_template_agent_addr; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_flows_template_agent_addr ON flows_template USING btree (agent_addr);


--
-- Name: index_flows_template_dst_addr; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_flows_template_dst_addr ON flows_template USING btree (dst_addr);


--
-- Name: index_flows_template_dst_port; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_flows_template_dst_port ON flows_template USING btree (dst_port);


--
-- Name: index_flows_template_dstaddr_agent_timestamp_ifindexin; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_flows_template_dstaddr_agent_timestamp_ifindexin ON flows_template USING btree (dst_addr, agent_addr, flow_timestamp, if_index_in);


--
-- Name: index_flows_template_dstport_agent_timestamp_ifindexin; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_flows_template_dstport_agent_timestamp_ifindexin ON flows_template USING btree (dst_port, agent_addr, flow_timestamp, if_index_in);


--
-- Name: index_flows_template_foo; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_flows_template_foo ON flows_template USING btree (if_index_in, agent_addr, flow_packets, flow_octets);


--
-- Name: index_flows_template_if_index_in; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_flows_template_if_index_in ON flows_template USING btree (if_index_in);


--
-- Name: index_flows_template_if_index_out; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_flows_template_if_index_out ON flows_template USING btree (if_index_out);


--
-- Name: index_flows_template_ifindexin_timestamp_agent; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_flows_template_ifindexin_timestamp_agent ON flows_template USING btree (if_index_in, flow_timestamp, agent_addr);


--
-- Name: index_flows_template_proto_agent_timestamp_dstport_ifindexin; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_flows_template_proto_agent_timestamp_dstport_ifindexin ON flows_template USING btree (protocol, agent_addr, flow_timestamp, dst_port, if_index_in);


--
-- Name: index_flows_template_proto_agent_timestamp_srcport_ifindexin; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_flows_template_proto_agent_timestamp_srcport_ifindexin ON flows_template USING btree (protocol, agent_addr, flow_timestamp, src_port, if_index_in);


--
-- Name: index_flows_template_src_addr; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_flows_template_src_addr ON flows_template USING btree (src_addr);


--
-- Name: index_flows_template_src_port; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_flows_template_src_port ON flows_template USING btree (src_port);


--
-- Name: index_flows_template_srcaddr_agent_timestamp_ifindexin; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_flows_template_srcaddr_agent_timestamp_ifindexin ON flows_template USING btree (src_addr, agent_addr, flow_timestamp, if_index_in);


--
-- Name: index_flows_template_srcaddrport_dstaddrport; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_flows_template_srcaddrport_dstaddrport ON flows_template USING btree (src_addr, src_port, dst_addr, dst_port);


--
-- Name: index_flows_template_srcport_agent_timestamp_ifindexin; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_flows_template_srcport_agent_timestamp_ifindexin ON flows_template USING btree (src_port, agent_addr, flow_timestamp, if_index_in);


--
-- Name: index_flows_template_timestamp; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_flows_template_timestamp ON flows_template USING btree (flow_timestamp);


--
-- Name: index_groups_members_device_addr; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_groups_members_device_addr ON groups_members USING btree (device_addr);


--
-- Name: index_groups_members_group_id; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_groups_members_group_id ON groups_members USING btree (group_id);


--
-- Name: index_interfaces_device_addr; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_interfaces_device_addr ON interfaces USING btree (device_addr);


--
-- Name: index_interfaces_id; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_interfaces_id ON interfaces USING btree (id);


--
-- Name: index_protocols_custom_number; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_protocols_custom_number ON protocols_custom USING btree (number);


--
-- Name: index_protocols_default_number; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_protocols_default_number ON protocols_default USING btree (number);


--
-- Name: index_services_custom_port; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_services_custom_port ON services_custom USING btree (port);


--
-- Name: index_services_default_port; Type: INDEX; Schema: public; Owner: nfdb_admin; Tablespace: 
--

CREATE INDEX index_services_default_port ON services_default USING btree (port);


--
-- Name: insert_flows_trigger; Type: TRIGGER; Schema: public; Owner: nfdb_admin
--

CREATE TRIGGER insert_flows_trigger
    BEFORE INSERT ON flows_template
    FOR EACH ROW
    EXECUTE PROCEDURE flows_insert_trigger();


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: devices; Type: ACL; Schema: public; Owner: nfdb_admin
--

REVOKE ALL ON TABLE devices FROM PUBLIC;
REVOKE ALL ON TABLE devices FROM nfdb_admin;
GRANT ALL ON TABLE devices TO nfdb_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE devices TO nfdb_user;


--
-- Name: flows_template; Type: ACL; Schema: public; Owner: nfdb_admin
--

REVOKE ALL ON TABLE flows_template FROM PUBLIC;
REVOKE ALL ON TABLE flows_template FROM nfdb_admin;
GRANT ALL ON TABLE flows_template TO nfdb_admin;
GRANT SELECT,INSERT,UPDATE ON TABLE flows_template TO nfdb_user;


--
-- Name: groups; Type: ACL; Schema: public; Owner: nfdb_admin
--

REVOKE ALL ON TABLE groups FROM PUBLIC;
REVOKE ALL ON TABLE groups FROM nfdb_admin;
GRANT ALL ON TABLE groups TO nfdb_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE groups TO nfdb_user;


--
-- Name: groups_members; Type: ACL; Schema: public; Owner: nfdb_admin
--

REVOKE ALL ON TABLE groups_members FROM PUBLIC;
REVOKE ALL ON TABLE groups_members FROM nfdb_admin;
GRANT ALL ON TABLE groups_members TO nfdb_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE groups_members TO nfdb_user;


--
-- Name: interfaces; Type: ACL; Schema: public; Owner: nfdb_admin
--

REVOKE ALL ON TABLE interfaces FROM PUBLIC;
REVOKE ALL ON TABLE interfaces FROM nfdb_admin;
GRANT ALL ON TABLE interfaces TO nfdb_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE interfaces TO nfdb_user;


--
-- Name: protocols_custom; Type: ACL; Schema: public; Owner: nfdb_admin
--

REVOKE ALL ON TABLE protocols_custom FROM PUBLIC;
REVOKE ALL ON TABLE protocols_custom FROM nfdb_admin;
GRANT ALL ON TABLE protocols_custom TO nfdb_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE protocols_custom TO nfdb_user;


--
-- Name: protocols_default; Type: ACL; Schema: public; Owner: nfdb_admin
--

REVOKE ALL ON TABLE protocols_default FROM PUBLIC;
REVOKE ALL ON TABLE protocols_default FROM nfdb_admin;
GRANT ALL ON TABLE protocols_default TO nfdb_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE protocols_default TO nfdb_user;


--
-- Name: services_custom; Type: ACL; Schema: public; Owner: nfdb_admin
--

REVOKE ALL ON TABLE services_custom FROM PUBLIC;
REVOKE ALL ON TABLE services_custom FROM nfdb_admin;
GRANT ALL ON TABLE services_custom TO nfdb_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE services_custom TO nfdb_user;


--
-- Name: services_default; Type: ACL; Schema: public; Owner: nfdb_admin
--

REVOKE ALL ON TABLE services_default FROM PUBLIC;
REVOKE ALL ON TABLE services_default FROM nfdb_admin;
GRANT ALL ON TABLE services_default TO nfdb_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE services_default TO nfdb_user;


--
-- Data for Name: services_default; Type: TABLE DATA; Schema: public; Owner: nfdb_admin
--

INSERT INTO services_default (name, port) VALUES ('tcpmux', 1);
INSERT INTO services_default (name, port) VALUES ('rje', 5);
INSERT INTO services_default (name, port) VALUES ('echo', 7);
INSERT INTO services_default (name, port) VALUES ('discard', 9);
INSERT INTO services_default (name, port) VALUES ('systat', 11);
INSERT INTO services_default (name, port) VALUES ('daytime', 13);
INSERT INTO services_default (name, port) VALUES ('qotd', 17);
INSERT INTO services_default (name, port) VALUES ('msp', 18);
INSERT INTO services_default (name, port) VALUES ('chargen', 19);
INSERT INTO services_default (name, port) VALUES ('ftp-data', 20);
INSERT INTO services_default (name, port) VALUES ('ftp', 21);
INSERT INTO services_default (name, port) VALUES ('ssh', 22);
INSERT INTO services_default (name, port) VALUES ('telnet', 23);
INSERT INTO services_default (name, port) VALUES ('smtp', 25);
INSERT INTO services_default (name, port) VALUES ('time', 37);
INSERT INTO services_default (name, port) VALUES ('rlp', 39);
INSERT INTO services_default (name, port) VALUES ('nameserver', 42);
INSERT INTO services_default (name, port) VALUES ('nicname', 43);
INSERT INTO services_default (name, port) VALUES ('tacacs', 49);
INSERT INTO services_default (name, port) VALUES ('re-mail-ck', 50);
INSERT INTO services_default (name, port) VALUES ('domain', 53);
INSERT INTO services_default (name, port) VALUES ('whois++', 63);
INSERT INTO services_default (name, port) VALUES ('bootps', 67);
INSERT INTO services_default (name, port) VALUES ('bootpc', 68);
INSERT INTO services_default (name, port) VALUES ('tftp', 69);
INSERT INTO services_default (name, port) VALUES ('gopher', 70);
INSERT INTO services_default (name, port) VALUES ('netrjs-1', 71);
INSERT INTO services_default (name, port) VALUES ('netrjs-2', 72);
INSERT INTO services_default (name, port) VALUES ('netrjs-3', 73);
INSERT INTO services_default (name, port) VALUES ('netrjs-4', 74);
INSERT INTO services_default (name, port) VALUES ('finger', 79);
INSERT INTO services_default (name, port) VALUES ('http', 80);
INSERT INTO services_default (name, port) VALUES ('kerberos', 88);
INSERT INTO services_default (name, port) VALUES ('supdup', 95);
INSERT INTO services_default (name, port) VALUES ('hostname', 101);
INSERT INTO services_default (name, port) VALUES ('iso-tsap', 102);
INSERT INTO services_default (name, port) VALUES ('csnet-ns', 105);
INSERT INTO services_default (name, port) VALUES ('rtelnet', 107);
INSERT INTO services_default (name, port) VALUES ('pop2', 109);
INSERT INTO services_default (name, port) VALUES ('pop3', 110);
INSERT INTO services_default (name, port) VALUES ('sunrpc', 111);
INSERT INTO services_default (name, port) VALUES ('auth', 113);
INSERT INTO services_default (name, port) VALUES ('sftp', 115);
INSERT INTO services_default (name, port) VALUES ('uucp-path', 117);
INSERT INTO services_default (name, port) VALUES ('nntp', 119);
INSERT INTO services_default (name, port) VALUES ('ntp', 123);
INSERT INTO services_default (name, port) VALUES ('netbios-ns', 137);
INSERT INTO services_default (name, port) VALUES ('netbios-dgm', 138);
INSERT INTO services_default (name, port) VALUES ('netbios-ssn', 139);
INSERT INTO services_default (name, port) VALUES ('imap', 143);
INSERT INTO services_default (name, port) VALUES ('snmp', 161);
INSERT INTO services_default (name, port) VALUES ('snmptrap', 162);
INSERT INTO services_default (name, port) VALUES ('cmip-man', 163);
INSERT INTO services_default (name, port) VALUES ('cmip-agent', 164);
INSERT INTO services_default (name, port) VALUES ('mailq', 174);
INSERT INTO services_default (name, port) VALUES ('xdmcp', 177);
INSERT INTO services_default (name, port) VALUES ('nextstep', 178);
INSERT INTO services_default (name, port) VALUES ('bgp', 179);
INSERT INTO services_default (name, port) VALUES ('prospero', 191);
INSERT INTO services_default (name, port) VALUES ('irc', 194);
INSERT INTO services_default (name, port) VALUES ('smux', 199);
INSERT INTO services_default (name, port) VALUES ('at-rtmp', 201);
INSERT INTO services_default (name, port) VALUES ('at-nbp', 202);
INSERT INTO services_default (name, port) VALUES ('at-echo', 204);
INSERT INTO services_default (name, port) VALUES ('at-zis', 206);
INSERT INTO services_default (name, port) VALUES ('qmtp', 209);
INSERT INTO services_default (name, port) VALUES ('z39.50', 210);
INSERT INTO services_default (name, port) VALUES ('ipx', 213);
INSERT INTO services_default (name, port) VALUES ('imap3', 220);
INSERT INTO services_default (name, port) VALUES ('link', 245);
INSERT INTO services_default (name, port) VALUES ('fatserv', 347);
INSERT INTO services_default (name, port) VALUES ('rsvp_tunnel', 363);
INSERT INTO services_default (name, port) VALUES ('rpc2portmap', 369);
INSERT INTO services_default (name, port) VALUES ('codaauth2', 370);
INSERT INTO services_default (name, port) VALUES ('ulistproc', 372);
INSERT INTO services_default (name, port) VALUES ('ldap', 389);
INSERT INTO services_default (name, port) VALUES ('svrloc', 427);
INSERT INTO services_default (name, port) VALUES ('mobileip-agent', 434);
INSERT INTO services_default (name, port) VALUES ('mobilip-mn', 435);
INSERT INTO services_default (name, port) VALUES ('https', 443);
INSERT INTO services_default (name, port) VALUES ('snpp', 444);
INSERT INTO services_default (name, port) VALUES ('microsoft-ds', 445);
INSERT INTO services_default (name, port) VALUES ('kpasswd', 464);
INSERT INTO services_default (name, port) VALUES ('photuris', 468);
INSERT INTO services_default (name, port) VALUES ('saft', 487);
INSERT INTO services_default (name, port) VALUES ('gss-http', 488);
INSERT INTO services_default (name, port) VALUES ('pim-rp-disc', 496);
INSERT INTO services_default (name, port) VALUES ('isakmp', 500);
INSERT INTO services_default (name, port) VALUES ('gdomap', 538);
INSERT INTO services_default (name, port) VALUES ('iiop', 535);
INSERT INTO services_default (name, port) VALUES ('dhcpv6-client', 546);
INSERT INTO services_default (name, port) VALUES ('dhcpv6-server', 547);
INSERT INTO services_default (name, port) VALUES ('rtsp', 554);
INSERT INTO services_default (name, port) VALUES ('nntps', 563);
INSERT INTO services_default (name, port) VALUES ('whoami', 565);
INSERT INTO services_default (name, port) VALUES ('submission', 587);
INSERT INTO services_default (name, port) VALUES ('npmp-local', 610);
INSERT INTO services_default (name, port) VALUES ('npmp-gui', 611);
INSERT INTO services_default (name, port) VALUES ('hmmp-ind', 612);
INSERT INTO services_default (name, port) VALUES ('ipp', 631);
INSERT INTO services_default (name, port) VALUES ('ldaps', 636);
INSERT INTO services_default (name, port) VALUES ('acap', 674);
INSERT INTO services_default (name, port) VALUES ('ha-cluster', 694);
INSERT INTO services_default (name, port) VALUES ('kerberos-adm', 749);
INSERT INTO services_default (name, port) VALUES ('kerberos-iv', 750);
INSERT INTO services_default (name, port) VALUES ('webster', 765);
INSERT INTO services_default (name, port) VALUES ('phonebook', 767);
INSERT INTO services_default (name, port) VALUES ('rsync', 873);
INSERT INTO services_default (name, port) VALUES ('telnets', 992);
INSERT INTO services_default (name, port) VALUES ('imaps', 993);
INSERT INTO services_default (name, port) VALUES ('ircs', 994);
INSERT INTO services_default (name, port) VALUES ('pop3s', 995);
INSERT INTO services_default (name, port) VALUES ('exec', 512);
INSERT INTO services_default (name, port) VALUES ('biff', 512);
INSERT INTO services_default (name, port) VALUES ('login', 513);
INSERT INTO services_default (name, port) VALUES ('who', 513);
INSERT INTO services_default (name, port) VALUES ('shell', 514);
INSERT INTO services_default (name, port) VALUES ('syslog', 514);
INSERT INTO services_default (name, port) VALUES ('printer', 515);
INSERT INTO services_default (name, port) VALUES ('talk', 517);
INSERT INTO services_default (name, port) VALUES ('ntalk', 518);
INSERT INTO services_default (name, port) VALUES ('utime', 519);
INSERT INTO services_default (name, port) VALUES ('efs', 520);
INSERT INTO services_default (name, port) VALUES ('router', 520);
INSERT INTO services_default (name, port) VALUES ('ripng', 521);
INSERT INTO services_default (name, port) VALUES ('timed', 525);
INSERT INTO services_default (name, port) VALUES ('tempo', 526);
INSERT INTO services_default (name, port) VALUES ('courier', 530);
INSERT INTO services_default (name, port) VALUES ('conference', 531);
INSERT INTO services_default (name, port) VALUES ('netnews', 532);
INSERT INTO services_default (name, port) VALUES ('netwall', 533);
INSERT INTO services_default (name, port) VALUES ('uucp', 540);
INSERT INTO services_default (name, port) VALUES ('klogin', 543);
INSERT INTO services_default (name, port) VALUES ('kshell', 544);
INSERT INTO services_default (name, port) VALUES ('afpovertcp', 548);
INSERT INTO services_default (name, port) VALUES ('remotefs', 556);
INSERT INTO services_default (name, port) VALUES ('socks', 1080);
INSERT INTO services_default (name, port) VALUES ('bvcontrol', 1236);
INSERT INTO services_default (name, port) VALUES ('h323hostcallsc', 1300);
INSERT INTO services_default (name, port) VALUES ('ms-sql-s', 1433);
INSERT INTO services_default (name, port) VALUES ('ms-sql-m', 1434);
INSERT INTO services_default (name, port) VALUES ('ica', 1494);
INSERT INTO services_default (name, port) VALUES ('wins', 1512);
INSERT INTO services_default (name, port) VALUES ('ingreslock', 1524);
INSERT INTO services_default (name, port) VALUES ('prospero-np', 1525);
INSERT INTO services_default (name, port) VALUES ('datametrics', 1645);
INSERT INTO services_default (name, port) VALUES ('sa-msg-port', 1646);
INSERT INTO services_default (name, port) VALUES ('kermit', 1649);
INSERT INTO services_default (name, port) VALUES ('l2tp', 1701);
INSERT INTO services_default (name, port) VALUES ('h323gatedisc', 1718);
INSERT INTO services_default (name, port) VALUES ('h323gatestat', 1719);
INSERT INTO services_default (name, port) VALUES ('h323hostcall', 1720);
INSERT INTO services_default (name, port) VALUES ('tftp-mcast', 1758);
INSERT INTO services_default (name, port) VALUES ('mtftp', 1759);
INSERT INTO services_default (name, port) VALUES ('hello', 1789);
INSERT INTO services_default (name, port) VALUES ('radius', 1812);
INSERT INTO services_default (name, port) VALUES ('radius-acct', 1813);
INSERT INTO services_default (name, port) VALUES ('mtp', 1911);
INSERT INTO services_default (name, port) VALUES ('hsrp', 1985);
INSERT INTO services_default (name, port) VALUES ('licensedaemon', 1986);
INSERT INTO services_default (name, port) VALUES ('gdp-port', 1997);
INSERT INTO services_default (name, port) VALUES ('nfs', 2049);
INSERT INTO services_default (name, port) VALUES ('zephyr-srv', 2102);
INSERT INTO services_default (name, port) VALUES ('zephyr-clt', 2103);
INSERT INTO services_default (name, port) VALUES ('zephyr-hm', 2104);
INSERT INTO services_default (name, port) VALUES ('cvspserver', 2401);
INSERT INTO services_default (name, port) VALUES ('venus', 2430);
INSERT INTO services_default (name, port) VALUES ('venus-se', 2431);
INSERT INTO services_default (name, port) VALUES ('codasrv', 2432);
INSERT INTO services_default (name, port) VALUES ('codasrv-se', 2433);
INSERT INTO services_default (name, port) VALUES ('hpstgmgr', 2600);
INSERT INTO services_default (name, port) VALUES ('discp-client', 2601);
INSERT INTO services_default (name, port) VALUES ('discp-server', 2602);
INSERT INTO services_default (name, port) VALUES ('servicemeter', 2603);
INSERT INTO services_default (name, port) VALUES ('nsc-ccs', 2604);
INSERT INTO services_default (name, port) VALUES ('nsc-posa', 2605);
INSERT INTO services_default (name, port) VALUES ('netmon', 2606);
INSERT INTO services_default (name, port) VALUES ('corbaloc', 2809);
INSERT INTO services_default (name, port) VALUES ('icpv2', 3130);
INSERT INTO services_default (name, port) VALUES ('mysql', 3306);
INSERT INTO services_default (name, port) VALUES ('trnsprntproxy', 3346);
INSERT INTO services_default (name, port) VALUES ('pxe', 4011);
INSERT INTO services_default (name, port) VALUES ('rwhois', 4321);
INSERT INTO services_default (name, port) VALUES ('krb524', 4444);
INSERT INTO services_default (name, port) VALUES ('rfe', 5002);
INSERT INTO services_default (name, port) VALUES ('cfengine', 5308);
INSERT INTO services_default (name, port) VALUES ('cvsup', 5999);
INSERT INTO services_default (name, port) VALUES ('x11', 6000);
INSERT INTO services_default (name, port) VALUES ('afs3-fileserver', 7000);
INSERT INTO services_default (name, port) VALUES ('afs3-callback', 7001);
INSERT INTO services_default (name, port) VALUES ('afs3-prserver', 7002);
INSERT INTO services_default (name, port) VALUES ('afs3-vlserver', 7003);
INSERT INTO services_default (name, port) VALUES ('afs3-kaserver', 7004);
INSERT INTO services_default (name, port) VALUES ('afs3-volser', 7005);
INSERT INTO services_default (name, port) VALUES ('afs3-errors', 7006);
INSERT INTO services_default (name, port) VALUES ('afs3-bos', 7007);
INSERT INTO services_default (name, port) VALUES ('afs3-update', 7008);
INSERT INTO services_default (name, port) VALUES ('afs3-rmtsys', 7009);
INSERT INTO services_default (name, port) VALUES ('sd', 9876);
INSERT INTO services_default (name, port) VALUES ('amanda', 10080);
INSERT INTO services_default (name, port) VALUES ('pgpkeyserver', 11371);
INSERT INTO services_default (name, port) VALUES ('h323callsigalt', 11720);
INSERT INTO services_default (name, port) VALUES ('bprd', 13720);
INSERT INTO services_default (name, port) VALUES ('bpdbm', 13721);
INSERT INTO services_default (name, port) VALUES ('bpjava-msvc', 13722);
INSERT INTO services_default (name, port) VALUES ('vnetd', 13724);
INSERT INTO services_default (name, port) VALUES ('bpcd', 13782);
INSERT INTO services_default (name, port) VALUES ('vopied', 13783);
INSERT INTO services_default (name, port) VALUES ('wnn6', 22273);
INSERT INTO services_default (name, port) VALUES ('quake', 26000);
INSERT INTO services_default (name, port) VALUES ('wnn6-ds', 26208);
INSERT INTO services_default (name, port) VALUES ('traceroute', 33434);
INSERT INTO services_default (name, port) VALUES ('kerberos_master', 751);
INSERT INTO services_default (name, port) VALUES ('passwd_server', 752);
INSERT INTO services_default (name, port) VALUES ('krbupdate', 760);
INSERT INTO services_default (name, port) VALUES ('kpop', 1109);
INSERT INTO services_default (name, port) VALUES ('knetd', 2053);
INSERT INTO services_default (name, port) VALUES ('krb5_prop', 754);
INSERT INTO services_default (name, port) VALUES ('eklogin', 2105);
INSERT INTO services_default (name, port) VALUES ('supfilesrv', 871);
INSERT INTO services_default (name, port) VALUES ('supfiledbg', 1127);
INSERT INTO services_default (name, port) VALUES ('netstat', 15);
INSERT INTO services_default (name, port) VALUES ('linuxconf', 98);
INSERT INTO services_default (name, port) VALUES ('poppassd', 106);
INSERT INTO services_default (name, port) VALUES ('smtps', 465);
INSERT INTO services_default (name, port) VALUES ('gii', 616);
INSERT INTO services_default (name, port) VALUES ('omirr', 808);
INSERT INTO services_default (name, port) VALUES ('swat', 901);
INSERT INTO services_default (name, port) VALUES ('rndc', 953);
INSERT INTO services_default (name, port) VALUES ('skkserv', 1178);
INSERT INTO services_default (name, port) VALUES ('xtel', 1313);
INSERT INTO services_default (name, port) VALUES ('support', 1529);
INSERT INTO services_default (name, port) VALUES ('cfinger', 2003);
INSERT INTO services_default (name, port) VALUES ('ninstall', 2150);
INSERT INTO services_default (name, port) VALUES ('afbackup', 2988);
INSERT INTO services_default (name, port) VALUES ('squid', 3128);
INSERT INTO services_default (name, port) VALUES ('prsvp', 3455);
INSERT INTO services_default (name, port) VALUES ('postgres', 5432);
INSERT INTO services_default (name, port) VALUES ('fax', 4557);
INSERT INTO services_default (name, port) VALUES ('hylafax', 4559);
INSERT INTO services_default (name, port) VALUES ('sgi-dgl', 5232);
INSERT INTO services_default (name, port) VALUES ('noclog', 5354);
INSERT INTO services_default (name, port) VALUES ('hostmon', 5355);
INSERT INTO services_default (name, port) VALUES ('canna', 5680);
INSERT INTO services_default (name, port) VALUES ('x11-ssh-offset', 6010);
INSERT INTO services_default (name, port) VALUES ('ircd', 6667);
INSERT INTO services_default (name, port) VALUES ('xfs', 7100);
INSERT INTO services_default (name, port) VALUES ('tircproxy', 7666);
INSERT INTO services_default (name, port) VALUES ('http-alt', 8008);
INSERT INTO services_default (name, port) VALUES ('webcache', 8080);
INSERT INTO services_default (name, port) VALUES ('tproxy', 8081);
INSERT INTO services_default (name, port) VALUES ('jetdirect', 9100);
INSERT INTO services_default (name, port) VALUES ('mandelspawn', 9359);
INSERT INTO services_default (name, port) VALUES ('kamanda', 10081);
INSERT INTO services_default (name, port) VALUES ('amandaidx', 10082);
INSERT INTO services_default (name, port) VALUES ('amidxtape', 10083);
INSERT INTO services_default (name, port) VALUES ('isdnlog', 20011);
INSERT INTO services_default (name, port) VALUES ('vboxd', 20012);
INSERT INTO services_default (name, port) VALUES ('wnn4_Kr', 22305);
INSERT INTO services_default (name, port) VALUES ('wnn4_Cn', 22289);
INSERT INTO services_default (name, port) VALUES ('wnn4_Tw', 22321);
INSERT INTO services_default (name, port) VALUES ('binkp', 24554);
INSERT INTO services_default (name, port) VALUES ('asp', 27374);
INSERT INTO services_default (name, port) VALUES ('tfido', 60177);
INSERT INTO services_default (name, port) VALUES ('fido', 60179);


--
-- Data for Name: protocols_default; Type: TABLE DATA; Schema: public; Owner: nfdb_admin
--

INSERT INTO protocols_default (name, number) VALUES ('ip', 0);
INSERT INTO protocols_default (name, number) VALUES ('icmp', 1);
INSERT INTO protocols_default (name, number) VALUES ('igmp', 2);
INSERT INTO protocols_default (name, number) VALUES ('ggp', 3);
INSERT INTO protocols_default (name, number) VALUES ('ipencap', 4);
INSERT INTO protocols_default (name, number) VALUES ('st', 5);
INSERT INTO protocols_default (name, number) VALUES ('tcp', 6);
INSERT INTO protocols_default (name, number) VALUES ('cbt', 7);
INSERT INTO protocols_default (name, number) VALUES ('egp', 8);
INSERT INTO protocols_default (name, number) VALUES ('igp', 9);
INSERT INTO protocols_default (name, number) VALUES ('bbn-rcc', 10);
INSERT INTO protocols_default (name, number) VALUES ('nvp', 11);
INSERT INTO protocols_default (name, number) VALUES ('pup', 12);
INSERT INTO protocols_default (name, number) VALUES ('argus', 13);
INSERT INTO protocols_default (name, number) VALUES ('emcon', 14);
INSERT INTO protocols_default (name, number) VALUES ('xnet', 15);
INSERT INTO protocols_default (name, number) VALUES ('chaos', 16);
INSERT INTO protocols_default (name, number) VALUES ('udp', 17);
INSERT INTO protocols_default (name, number) VALUES ('mux', 18);
INSERT INTO protocols_default (name, number) VALUES ('dcn', 19);
INSERT INTO protocols_default (name, number) VALUES ('hmp', 20);
INSERT INTO protocols_default (name, number) VALUES ('prm', 21);
INSERT INTO protocols_default (name, number) VALUES ('xns-idp', 22);
INSERT INTO protocols_default (name, number) VALUES ('trunk-1', 23);
INSERT INTO protocols_default (name, number) VALUES ('trunk-2', 24);
INSERT INTO protocols_default (name, number) VALUES ('leaf-1', 25);
INSERT INTO protocols_default (name, number) VALUES ('leaf-2', 26);
INSERT INTO protocols_default (name, number) VALUES ('rdp', 27);
INSERT INTO protocols_default (name, number) VALUES ('irtp', 28);
INSERT INTO protocols_default (name, number) VALUES ('iso-tp4', 29);
INSERT INTO protocols_default (name, number) VALUES ('netblt', 30);
INSERT INTO protocols_default (name, number) VALUES ('mfe-nsp', 31);
INSERT INTO protocols_default (name, number) VALUES ('merit-inp', 32);
INSERT INTO protocols_default (name, number) VALUES ('sep', 33);
INSERT INTO protocols_default (name, number) VALUES ('3pc', 34);
INSERT INTO protocols_default (name, number) VALUES ('idpr', 35);
INSERT INTO protocols_default (name, number) VALUES ('xtp', 36);
INSERT INTO protocols_default (name, number) VALUES ('ddp', 37);
INSERT INTO protocols_default (name, number) VALUES ('idpr-cmtp', 38);
INSERT INTO protocols_default (name, number) VALUES ('tp++', 39);
INSERT INTO protocols_default (name, number) VALUES ('il', 40);
INSERT INTO protocols_default (name, number) VALUES ('ipv6', 41);
INSERT INTO protocols_default (name, number) VALUES ('sdrp', 42);
INSERT INTO protocols_default (name, number) VALUES ('ipv6-route', 43);
INSERT INTO protocols_default (name, number) VALUES ('ipv6-frag', 44);
INSERT INTO protocols_default (name, number) VALUES ('idrp', 45);
INSERT INTO protocols_default (name, number) VALUES ('rsvp', 46);
INSERT INTO protocols_default (name, number) VALUES ('gre', 47);
INSERT INTO protocols_default (name, number) VALUES ('mhrp', 48);
INSERT INTO protocols_default (name, number) VALUES ('bna', 49);
INSERT INTO protocols_default (name, number) VALUES ('ipv6-crypt', 50);
INSERT INTO protocols_default (name, number) VALUES ('ipv6-auth', 51);
INSERT INTO protocols_default (name, number) VALUES ('i-nlsp', 52);
INSERT INTO protocols_default (name, number) VALUES ('swipe', 53);
INSERT INTO protocols_default (name, number) VALUES ('narp', 54);
INSERT INTO protocols_default (name, number) VALUES ('mobile', 55);
INSERT INTO protocols_default (name, number) VALUES ('tlsp', 56);
INSERT INTO protocols_default (name, number) VALUES ('skip', 57);
INSERT INTO protocols_default (name, number) VALUES ('ipv6-icmp', 58);
INSERT INTO protocols_default (name, number) VALUES ('ipv6-nonxt', 59);
INSERT INTO protocols_default (name, number) VALUES ('ipv6-opts', 60);
INSERT INTO protocols_default (name, number) VALUES ('cftp', 62);
INSERT INTO protocols_default (name, number) VALUES ('sat-expak', 64);
INSERT INTO protocols_default (name, number) VALUES ('kryptolan', 65);
INSERT INTO protocols_default (name, number) VALUES ('rvd', 66);
INSERT INTO protocols_default (name, number) VALUES ('ippc', 67);
INSERT INTO protocols_default (name, number) VALUES ('sat-mon', 69);
INSERT INTO protocols_default (name, number) VALUES ('visa', 70);
INSERT INTO protocols_default (name, number) VALUES ('ipcv', 71);
INSERT INTO protocols_default (name, number) VALUES ('cpnx', 72);
INSERT INTO protocols_default (name, number) VALUES ('cphb', 73);
INSERT INTO protocols_default (name, number) VALUES ('wsn', 74);
INSERT INTO protocols_default (name, number) VALUES ('pvp', 75);
INSERT INTO protocols_default (name, number) VALUES ('br-sat-mon', 76);
INSERT INTO protocols_default (name, number) VALUES ('sun-nd', 77);
INSERT INTO protocols_default (name, number) VALUES ('wb-mon', 78);
INSERT INTO protocols_default (name, number) VALUES ('wb-expak', 79);
INSERT INTO protocols_default (name, number) VALUES ('iso-ip', 80);
INSERT INTO protocols_default (name, number) VALUES ('vmtp', 81);
INSERT INTO protocols_default (name, number) VALUES ('secure-vmtp', 82);
INSERT INTO protocols_default (name, number) VALUES ('vines', 83);
INSERT INTO protocols_default (name, number) VALUES ('ttp', 84);
INSERT INTO protocols_default (name, number) VALUES ('nsfnet-igp', 85);
INSERT INTO protocols_default (name, number) VALUES ('dgp', 86);
INSERT INTO protocols_default (name, number) VALUES ('tcf', 87);
INSERT INTO protocols_default (name, number) VALUES ('eigrp', 88);
INSERT INTO protocols_default (name, number) VALUES ('ospf', 89);
INSERT INTO protocols_default (name, number) VALUES ('sprite-rpc', 90);
INSERT INTO protocols_default (name, number) VALUES ('larp', 91);
INSERT INTO protocols_default (name, number) VALUES ('mtp', 92);
INSERT INTO protocols_default (name, number) VALUES ('ax.25', 93);
INSERT INTO protocols_default (name, number) VALUES ('ipip', 94);
INSERT INTO protocols_default (name, number) VALUES ('micp', 95);
INSERT INTO protocols_default (name, number) VALUES ('scc-sp', 96);
INSERT INTO protocols_default (name, number) VALUES ('etherip', 97);
INSERT INTO protocols_default (name, number) VALUES ('encap', 98);
INSERT INTO protocols_default (name, number) VALUES ('gmtp', 100);
INSERT INTO protocols_default (name, number) VALUES ('ifmp', 101);
INSERT INTO protocols_default (name, number) VALUES ('pnni', 102);
INSERT INTO protocols_default (name, number) VALUES ('pim', 103);
INSERT INTO protocols_default (name, number) VALUES ('aris', 104);
INSERT INTO protocols_default (name, number) VALUES ('scps', 105);
INSERT INTO protocols_default (name, number) VALUES ('qnx', 106);
INSERT INTO protocols_default (name, number) VALUES ('a/n', 107);
INSERT INTO protocols_default (name, number) VALUES ('ipcomp', 108);
INSERT INTO protocols_default (name, number) VALUES ('snp', 109);
INSERT INTO protocols_default (name, number) VALUES ('compaq-peer', 110);
INSERT INTO protocols_default (name, number) VALUES ('ipx-in-ip', 111);
INSERT INTO protocols_default (name, number) VALUES ('vrrp', 112);
INSERT INTO protocols_default (name, number) VALUES ('pgm', 113);
INSERT INTO protocols_default (name, number) VALUES ('l2tp', 115);
INSERT INTO protocols_default (name, number) VALUES ('ddx', 116);
INSERT INTO protocols_default (name, number) VALUES ('iatp', 117);
INSERT INTO protocols_default (name, number) VALUES ('stp', 118);
INSERT INTO protocols_default (name, number) VALUES ('srp', 119);
INSERT INTO protocols_default (name, number) VALUES ('uti', 120);
INSERT INTO protocols_default (name, number) VALUES ('smp', 121);
INSERT INTO protocols_default (name, number) VALUES ('sm', 122);
INSERT INTO protocols_default (name, number) VALUES ('ptp', 123);
INSERT INTO protocols_default (name, number) VALUES ('isis', 124);
INSERT INTO protocols_default (name, number) VALUES ('fire', 125);
INSERT INTO protocols_default (name, number) VALUES ('crtp', 126);
INSERT INTO protocols_default (name, number) VALUES ('crdup', 127);
INSERT INTO protocols_default (name, number) VALUES ('sscopmce', 128);
INSERT INTO protocols_default (name, number) VALUES ('iplt', 129);
INSERT INTO protocols_default (name, number) VALUES ('sps', 130);
INSERT INTO protocols_default (name, number) VALUES ('pipe', 131);
INSERT INTO protocols_default (name, number) VALUES ('sctp', 132);
INSERT INTO protocols_default (name, number) VALUES ('fc', 133);


--
-- PostgreSQL database dump complete
--

