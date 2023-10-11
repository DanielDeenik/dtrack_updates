-- Usage: select * from api.daterange_active(array['user_id']);
-- Usage: select * from api.daterange_active();
-- TODO: Relook at this, I had trouble ordering the dateranges in the array_agg because of the DISTINCT keyword
CREATE
OR REPLACE FUNCTION api.daterange_active (dims TEXT[] DEFAULT '{}') RETURNS TABLE (
  id BIGINT,
  dimensions JSONB,
  years DATERANGE[],
  months DATERANGE[],
  weeks DATERANGE[],
  days DATERANGE[]
) SECURITY INVOKER LANGUAGE plpgsql AS $$
DECLARE
  dim TEXT;
  inner_dims TEXT := '';
  outer_dims TEXT;
  final_dims TEXT;
  group_by_list TEXT := 'GROUP BY ';
  final_group_by TEXT;
BEGIN
  FOR dim IN SELECT UNNEST(dims) LOOP
    inner_dims := inner_dims || format('%L, %I,', dim, dim);
    group_by_list := group_by_list || format('%I,', dim);
  END LOOP;
  inner_dims := rtrim(inner_dims, ',');
  group_by_list := rtrim(group_by_list, ',');
  outer_dims := CASE WHEN inner_dims = '' THEN 'NULL::jsonb as dimensions' ELSE format('jsonb_build_object(%s) as dimensions', inner_dims) END;
  final_dims := CASE WHEN inner_dims = '' THEN 'NULL::jsonb as dimensions' ELSE 'dimensions' END;
  group_by_list := CASE WHEN inner_dims = '' THEN '' ELSE group_by_list END;
  final_group_by := CASE WHEN inner_dims = '' THEN '' ELSE 'GROUP BY dimensions' END;
  RETURN QUERY EXECUTE format('
    WITH cte AS (
      SELECT
        %s,
        array_agg(
          DISTINCT daterange (
            date_trunc(''year'', date)::date,
            (date_trunc(''year'', date) + interval ''1 year'')::date,
            ''[)''
          )
        ) AS years,
        array_agg(
          DISTINCT daterange (
            date_trunc(''month'', date)::date,
            (date_trunc(''month'', date) + interval ''1 month'')::date,
            ''[)''
          )
        ) AS months,
        array_agg(
          DISTINCT daterange (
            date_trunc(''week'', date)::date,
            (date_trunc(''week'', date) + interval ''1 week'')::date,
            ''[)''
          )
        ) AS weeks,
        array_agg(
          DISTINCT daterange (
            date_trunc(''day'', date)::date,
            (date_trunc(''day'', date) + interval ''1 day'')::date,
            ''[)''
          )
        ) AS days
      FROM
        internal.time_trackings
        %s
    ),
    expanded_dates AS (
      SELECT
        %s,
        unnest(years) AS year,
        unnest(months) AS month,
        unnest(weeks) AS week,
        unnest(days) AS day
      FROM cte
    )
    SELECT
      ROW_NUMBER() OVER () AS id,
      %s,
      array_agg(year ORDER BY year DESC) FILTER (WHERE year IS NOT NULL) AS years,
      array_agg(month ORDER BY month DESC) FILTER (WHERE month IS NOT NULL) AS months,
      array_agg(week ORDER BY week DESC) FILTER (WHERE week IS NOT NULL) AS weeks,
      array_agg(day ORDER BY day DESC) FILTER (WHERE day IS NOT NULL) AS days
    FROM expanded_dates
    %s
  ', outer_dims, group_by_list, final_dims, final_dims, final_group_by);
END;
$$;

GRANT
EXECUTE ON FUNCTION api.daterange_active TO basic;

-- Usage: select * from internal.timetracking_summary(array['user_id', 'project_id']);
-- Usage: select * from internal.timetracking_summary(array['user_id', 'project_id', 'aow_id', 'activity_id', 'daterange'], date_part := 'week');
-- Usage: select * from internal.timetracking_summary(array['user_id', 'daterange', 'aow_id', 'project_id', 'activity_id'], date_part := 'month');
-- Usage: select * from internal.timetracking_summary(array['user_id', 'aow_id', 'daterange', 'project_id', 'activity_id'], date_part := 'month');
-- Usage: select * from internal.timetracking_summary(array['user_id', 'project_id', 'daterange', 'activity_id', 'aow_id']);
-- Usage: select * from internal.timetracking_summary(array['user_id', 'project_id', 'aow_id', 'activity_id', 'daterange']);
-- Usage: select * from internal.timetracking_summary(array['daterange', 'user_id', 'project_id'], date_part := 'month');
-- Usage: select * from internal.timetracking_summary(array['daterange', 'project_id']);
-- Usage: select * from internal.timetracking_summary(array['project_id']);
-- Usage: select * from internal.timetracking_summary(array['daterange']);
-- Usage: select total_duration from internal.timetracking_summary();
CREATE
OR REPLACE FUNCTION internal.timetracking_summary (
  axes TEXT[] DEFAULT ARRAY[]::TEXT[],
  date_part TEXT DEFAULT 'month'
) RETURNS TABLE (
  user_id INTEGER,
  aow_id INTEGER,
  project_id INTEGER,
  activity_id INTEGER,
  daterange DATERANGE,
  total_duration NUMERIC
) SECURITY INVOKER LANGUAGE plpgsql AS $$
DECLARE
  valid_axes TEXT[];
  axis_value TEXT;
  axis_type TEXT;
  foreign_axes TEXT[];
  null_axes TEXT[];
  group_by_columns TEXT;
  select_columns TEXT;
BEGIN
  -- Define the valid axes values
  valid_axes := ARRAY['user_id', 'aow_id', 'project_id', 'activity_id', 'daterange'];

  -- Check if any elements in the axes argument are not in the valid axes array
  foreign_axes := (select array(select unnest(axes) except select unnest(valid_axes)));

  -- If there are any invalid elements, raise an exception
  IF foreign_axes <> array[]::text[] THEN
    RAISE EXCEPTION 'Invalid axes arguments: %', foreign_axes;
  END IF;

  -- Construct the select and group by columns for the final query using the valid axes array and the axes argument
  select_columns := array_to_string(valid_axes, ', ');
  group_by_columns := CASE
    WHEN array_length(axes, 1) IS NULL THEN ''
    ELSE format('GROUP BY %s', array_to_string(axes, ', '))
  END;

  -- Check if any elements in the valid axes array are not in the axes argument
  null_axes := (SELECT array_agg(x) FROM (SELECT unnest(valid_axes) EXCEPT SELECT unnest(axes)) t(x));

  -- If there are any such elements, set their values to NULL in the select columns
  IF null_axes IS NOT NULL THEN
    FOREACH axis_value IN ARRAY null_axes LOOP
      IF position('_id' in axis_value) > 0 THEN
        axis_type := 'INTEGER';
      ELSIF axis_value = 'daterange' THEN
        axis_type := 'DATERANGE';
      ELSE
        axis_type := 'TEXT';
      END IF;
      select_columns := replace(select_columns, axis_value, format('NULL::%s as %s', axis_type, axis_value));
    END LOOP;
  END IF;

  -- Check if 'daterange' is in the axes argument. If it is, update the select columns to include a date range calculation using the date_part argument.
  IF 'daterange' = ANY(axes) THEN
    select_columns := replace(select_columns, 'daterange', format('daterange(date_trunc(%L, date)::date, (date_trunc(%L, date) + interval ''1 %s'')::date, ''[)'') as daterange', date_part, date_part, date_part));
  END IF;

  -- Add a column for the total duration to the select columns
  select_columns := select_columns || ', ' || 'TRUNC(EXTRACT(epoch FROM SUM(duration))/3600, 2) as total_duration';

  -- Construct and execute a dynamic query using the constructed select and group by columns
  RETURN QUERY EXECUTE format('
    SELECT %s FROM internal.time_trackings %s ORDER BY total_duration DESC
  ', select_columns, group_by_columns);
END;
$$;

GRANT
EXECUTE ON FUNCTION internal.timetracking_summary TO basic;

-- Usage: select "user", project, total_duration from api.timetracking_summary_export(array['user', 'project']);
-- Usage: select * from api.timetracking_summary_export(array['user', 'project', 'aow', 'activity', 'daterange'], date_part := 'week');
-- Usage: select * from api.timetracking_summary_export(array['user', 'daterange', 'aow', 'project', 'activity'], date_part := 'month');
-- Usage: select * from api.timetracking_summary_export(array['user', 'project', 'aow', 'activity', 'daterange'], date_part := 'month');
-- Usage: select * from api.timetracking_summary_export(array['user', 'aow', 'daterange', 'project', 'activity'], date_part := 'month');
-- Usage: select * from api.timetracking_summary_export(array['user', 'project', 'daterange', 'activity', 'aow']);
-- Usage: select * from api.timetracking_summary_export(array['user', 'project', 'aow', 'activity', 'daterange']);
-- Usage: select * from api.timetracking_summary_export(array['daterange', 'user', 'project'], date_part := 'month');
-- Usage: select * from api.timetracking_summary_export(array['daterange', 'project']);
-- Usage: select * from api.timetracking_summary_export(array['project']);
-- Usage: select * from api.timetracking_summary_export(array['daterange']);
-- Usage: select total_duration from api.timetracking_summary_export();
CREATE
OR REPLACE FUNCTION api.timetracking_summary_export (
  axes TEXT[] DEFAULT ARRAY[]::TEXT[],
  date_part TEXT DEFAULT 'month'
) RETURNS TABLE (
  id BIGINT,
  "user" JSONB,
  aow JSONB,
  project JSONB,
  activity JSONB,
  daterange DATERANGE,
  total_duration NUMERIC
) SECURITY INVOKER LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY EXECUTE format('
    SELECT
      ROW_NUMBER() OVER () AS id,
      NULLIF(jsonb_build_object(''id'', u.user_id, ''name'', u.username), jsonb_build_object(''id'', NULL, ''name'', NULL)) AS "user",
      NULLIF(jsonb_build_object(''id'', a.aow_id, ''name'', a.name), jsonb_build_object(''id'', NULL, ''name'', NULL)) AS aow,
      NULLIF(jsonb_build_object(''id'', p.project_id, ''name'', p.name), jsonb_build_object(''id'', NULL, ''name'', NULL)) AS project,
      NULLIF(jsonb_build_object(''id'', ac.activity_id, ''name'', ac.name), jsonb_build_object(''id'', NULL, ''name'', NULL)) AS activity,
      t.daterange,
      t.total_duration
    FROM internal.timetracking_summary(%L, %L) t
    LEFT JOIN auth.users AS u USING (user_id)
    LEFT JOIN internal.areas_of_work AS a USING (aow_id)
    LEFT JOIN internal.projects AS p USING (project_id)
    LEFT JOIN internal.activities AS ac USING (activity_id)
    ORDER BY total_duration DESC
  ', (SELECT array_agg(CASE WHEN axis != 'daterange' THEN axis || '_id' ELSE axis END) FROM unnest(axes) AS axis), date_part);
END;
$$;

GRANT
EXECUTE ON FUNCTION api.timetracking_summary_export TO basic;

-- Usage:
-- select * from api.timetracking_summary(array['user', 'project'], date_part := 'month', zoom_level := 0);
-- select * from api.timetracking_summary(array['user', 'project'], date_part := 'month', zoom_level := 1);
-- select * from api.timetracking_summary(array['user', 'project'], date_part := 'month', zoom_level := 2);
-- select * from api.timetracking_summary(array['user', 'project', 'aow', 'activity', 'daterange'], date_part := 'week');
-- select * from api.timetracking_summary(array['user', 'daterange', 'aow', 'project', 'activity'], date_part := 'month', zoom_level := 2);
-- select * from api.timetracking_summary(array['user', 'aow', 'daterange', 'project', 'activity'], date_part := 'month', zoom_level := 3);
-- select * from api.timetracking_summary(array['user', 'project', 'daterange', 'activity', 'aow'], zoom_level := 3);
-- select * from api.timetracking_summary(array['user', 'project', 'aow', 'activity', 'daterange'], zoom_level := 3);
-- select * from api.timetracking_summary(array['user',  'daterange'], date_part := 'month', zoom_level := 2);
-- select id, total_duration from api.timetracking_summary();
-- select to_char(lower(daterange), 'YYYY-MM-DD') as day, total_duration from
--   api.timetracking_summary(array['user', 'daterange'], date_part := 'day', zoom_level := 2)
--   where user_id = 2 and '[2023-04-01, 2023-05-01)'::daterange @> daterange order by daterange asc;
-- select * from api.timetracking_summary(array['daterange', 'user', 'aow', 'project', 'activity'], date_part := 'month', zoom_level := 1, filter_by := 'user', filter_ids := array[2]);
-- select * from api.timetracking_summary(array['daterange', 'aow', 'project', 'activity', 'user'], date_part := 'month', zoom_level := 1, filter_by := 'user', filter_ids := array[2]);
-- select * from api.timetracking_summary(array['daterange', 'aow', 'project', 'activity'], date_part := 'month', zoom_level := 2, filter_by := 'user', filter_ids := array[2]);
-- select * from api.timetracking_summary(array['daterange', 'aow', 'user', 'project', 'activity'], date_part := 'month', zoom_level := 3, filter_by := 'user', filter_ids := array[2]);
-- select * from api.timetracking_summary('{daterange,activity,user}'::TEXT[],date_part:='month',zoom_level:=1,filter_by:='user',filter_ids:='{2,3,7,8,10,11,12,23}'::INTEGER[]);
-- select * from api.timetracking_summary('{daterange,project}'::TEXT[],date_part:='month',zoom_level:=1,filter_by:='user',filter_ids:='{2,3,7,8,10,11,12,23}'::INTEGER[]);
-- select * from api.timetracking_summary ('{user,daterange}'::TEXT[],date_part:='day',zoom_level:=2);
CREATE
OR REPLACE FUNCTION api.timetracking_summary (
  axes TEXT[] DEFAULT ARRAY[]::TEXT[], -- axes to group data by
  date_part TEXT DEFAULT 'month', -- date part to use for grouping
  zoom_level INTEGER DEFAULT 0, -- level of detail for returned data
  filter_by TEXT DEFAULT NULL, -- axes to filter by
  filter_ids INTEGER[] DEFAULT ARRAY[]::INTEGER[] -- ID values to filter by
) RETURNS TABLE (
  id BIGINT,
  user_id INTEGER,
  aow_id INTEGER,
  project_id INTEGER,
  activity_id INTEGER,
  daterange daterange,
  total_duration NUMERIC,
  data jsonb
) LANGUAGE plpgsql IMMUTABLE SECURITY invoker AS $$
DECLARE
  valid_axes TEXT[]; -- array of valid axes
  foreign_axes TEXT[]; -- array of invalid axes
  axes_ids TEXT[]; -- array of column names for grouping
  query_text TEXT; -- dynamic query text
  cte_name TEXT; -- name of current CTE
  table_name TEXT; -- name of current table
  cte_select TEXT; -- SELECT statement for current CTE
  axes_select TEXT; -- SELECT statement for grouping columns
  null_select TEXT; -- SELECT statement for NULL columns
  cte_group_by TEXT; -- GROUP BY statement for current CTE
  foreign_table TEXT; -- name of foreign table for JOIN
  join_column TEXT; -- name of column for JOIN condition
  display_column TEXT; -- name of column to display in JSON data
  i INTEGER;
BEGIN
  valid_axes := ARRAY['user', 'aow', 'project', 'activity', 'daterange']; -- define valid axes
  -- check if provided axes are valid and raise exception if not
  foreign_axes := (select array(select unnest(axes) except select unnest(valid_axes)));
    IF foreign_axes <> array[]::text[] THEN
    RAISE EXCEPTION 'Invalid axes arguments: %', foreign_axes;
  END IF;
  -- generate array of column names for grouping based on provided axes
  axes_ids := (
    SELECT array_agg(CASE WHEN item != 'daterange' THEN item || '_id' ELSE item END)
    FROM UNNEST(
      CASE
        WHEN filter_by IS NOT NULL AND filter_by != ANY(axes) THEN array_cat(axes, array[filter_by])
        ELSE axes
      END
    ) AS item
  );
  query_text := format(
    'WITH summary_cte AS (
      SELECT %s, %stotal_duration, NULL::jsonb AS data
      FROM internal.timetracking_summary(%L::TEXT[], %L)
      %s
      %s
    ),',
    array_to_string(
      (
        SELECT array_agg(
          CASE
            WHEN item = ANY(axes) THEN
              CASE
                WHEN item != 'daterange' THEN item || '_id'
                ELSE item
              END
            ELSE
              CASE
                WHEN item != 'daterange' THEN 'NULL::INTEGER AS ' || item || '_id'
                ELSE 'NULL::DATERANGE AS ' || item
              END
          END
        )
        FROM UNNEST(valid_axes) AS item
      ),
      ','
    ),
    (
      CASE
        WHEN filter_by IS NOT NULL THEN 'SUM(total_duration) AS '
        ELSE ''
      END
    ),
    axes_ids,
    date_part,
    (
      CASE
        WHEN filter_by IS NOT NULL THEN format('WHERE %s_id = ANY (%L::INTEGER[])', filter_by, filter_ids)
        ELSE ''
      END
    ),
    (
      CASE
        WHEN filter_by IS NOT NULL THEN format(
          'GROUP BY %s',
          array_to_string(
            (
              SELECT array_agg(
                CASE
                  WHEN item != 'daterange' THEN item || '_id'
                  ELSE item
                END
              )
              FROM UNNEST(axes) AS item
            ),
            ','
          )
        )
        ELSE ''
      END
    )
  );
  -- loop through provided axes in reverse order to build nested CTEs for grouping and aggregating data at different levels of detail based on zoom_level argument.
  i := array_upper(axes, 1);
  WHILE i >= array_lower(axes, 1) LOOP
    -- generate SELECT statement for NULL columns to maintain consistent column order in all CTEs.
    null_select := (
      SELECT array_to_string(
        array_agg(
          CASE WHEN elem != 'daterange' THEN format('NULL::INTEGER AS %s_id', elem)
          ELSE format('NULL::DATERANGE AS %s', elem)
          END
        ), ', '
      ) FROM unnest(
        (SELECT ARRAY(SELECT unnest(valid_axes) EXCEPT SELECT unnest(axes))) || axes[i:]
      ) elem
    );
    -- set names for current CTE and table based on current axis.
    cte_name := format('%s_cte', axes[i]);
    table_name := format('%s_table', axes[i]);
    -- generate SELECT statement for grouping columns based on current axis.
    axes_select := array_to_string(
      ARRAY(
        SELECT format('%s.%s', format('%s_table', COALESCE(axes[i+1], 'summary')), elem)
        FROM unnest((axes_ids)[1:i-1]) elem
      ),
      ','
    );
    -- set foreign table, join column and display column based on current axis.
    IF axes[i] = 'user' THEN
      foreign_table := 'auth.users';
      join_column := 'user_id';
      display_column := 'username';
    ELSIF axes[i] = 'project' THEN
      foreign_table := 'internal.projects';
      join_column := 'project_id';
      display_column := 'name';
    ELSIF axes[i] = 'aow' THEN
      foreign_table := 'internal.areas_of_work';
      join_column := 'aow_id';
      display_column := 'name';
    ELSIF axes[i] = 'activity' THEN
      foreign_table := 'internal.activities';
      join_column := 'activity_id';
      display_column := 'name';
    ELSIF axes[i] = 'daterange' THEN
      foreign_table := 'summary_cte';
      join_column := 'daterange';
      display_column := 'daterange';
    END IF;
    -- generate GROUP BY statement for current CTE based on grouping columns.
    cte_group_by := format('GROUP BY %s', axes_select);
    -- add comma separator to axes_select if not empty.
    IF axes_select != '' THEN
      axes_select := axes_select || ',';
    END IF;
    -- generate SELECT statement for current CTE based on current axis and level of detail.
    IF i = array_upper(axes, 1) THEN
      cte_select := format(
        '%s %s, NULL::NUMERIC as total_duration, jsonb_agg(jsonb_build_object(''name'', %s_table.%s, ''value'', summary_table.total_duration)) AS data',
        axes_select,
        null_select,
        (CASE WHEN axes[i] != 'daterange' THEN axes[i] ELSE 'summary' END),
        display_column
      );
    ELSE
      cte_select := format(
        '%s %s, NULL::NUMERIC as total_duration, jsonb_agg(jsonb_build_object(''name'', %s_table.%s, ''children'', %s_table.data)) AS data',
        axes_select,
        null_select,
        (CASE WHEN axes[i] != 'daterange' THEN axes[i] ELSE 'summary' END),
        display_column,
        axes[i+1]
      );
    END IF;
    -- add current CTE to dynamic query with SELECT, FROM and LEFT JOIN statements.
    query_text := format(
      '%s %s AS (
        SELECT %s
        FROM %s AS %s
        %s
        %s
      ),',
      query_text,
      cte_name,
      cte_select,
      (CASE WHEN i = array_upper(axes, 1) THEN 'summary_cte' ELSE format('%s_cte', axes[i+1]) END),
      (CASE WHEN i = array_upper(axes, 1) THEN 'summary_table' ELSE format('%s_table', axes[i+1]) END),
      (
        CASE WHEN i = array_upper(axes, 1) AND foreign_table = 'summary_cte' THEN ''
        ELSE format(
          'LEFT JOIN %s AS %s USING (%s)',
          foreign_table,
          (CASE WHEN axes[i] = 'daterange' THEN 'summary_table' ELSE table_name END),
          join_column)
        END
      ),
      (CASE WHEN i = 1 THEN '' ELSE cte_group_by END)
    );
    i := i - 1;
  END LOOP;
  -- add final SELECT statement to dynamic query to return data at specified level of detail based on zoom_level argument.
  query_text := format(
    '%s SELECT
      ROW_NUMBER() OVER () AS id,
      user_id,
      aow_id,
      project_id,
      activity_id,
      daterange,
      total_duration,
      data
    FROM %s_cte AS %s_table;',
    rtrim(query_text, ','),
    (array_cat(axes, ARRAY['summary']))[zoom_level+1],
    (array_cat(axes, ARRAY['summary']))[zoom_level+1]
  );
  -- execute dynamic query and return results.
  RETURN QUERY EXECUTE query_text;
END;
$$;

GRANT
EXECUTE ON FUNCTION api.timetracking_summary TO basic;

-- Usage:
-- select day, duration from api.duration_calendar where user_id = 2 and daterange <@ '[2023-04-01, 2023-05-01)'::daterange;
CREATE OR REPLACE VIEW
  api.duration_calendar
WITH
  (security_invoker = on) AS
SELECT
  id,
  user_id,
  daterange,
  TO_CHAR(LOWER(daterange), 'YYYY-MM-DD') AS day,
  total_duration AS duration
FROM
  api.timetracking_summary (
    ARRAY['user', 'daterange'],
    date_part := 'day',
    zoom_level := 2
  )
ORDER BY
  daterange ASC;
