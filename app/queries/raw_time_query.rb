class RawTimeQuery < BaseQuery

  def self.with_relations(args = {})
    order_sql = sql_order_from_hash(args[:sort], permitted_column_names, 'sortable_bib_number')

    query = <<-SQL

    WITH existing_scope AS (#{existing_scope_sql}),
         raw_times_scoped AS (
           SELECT raw_times.*
           FROM raw_times
           INNER JOIN existing_scope ON existing_scope.id = raw_times.id)

    SELECT 
     r.*, 
     e.id AS effort_id,
     e.last_name AS effort_last_name,
     e.event_id, 
     s.split_id
    FROM raw_times_scoped r
    LEFT JOIN (
                SELECT ef.id, ef.event_id, ef.bib_number, ef.last_name, ev.event_group_id
                FROM efforts ef
                INNER JOIN events ev ON ef.event_id = ev.id
               ) e ON r.bib_number = e.bib_number::text
                   AND e.event_group_id = r.event_group_id
    LEFT JOIN LATERAL (
                SELECT a.split_id FROM aid_stations a
                INNER JOIN splits s ON a.split_id = s.id
                WHERE a.event_id = e.event_id
                AND s.parameterized_base_name = r.parameterized_split_name
                limit 1) s ON TRUE
    ORDER BY #{order_sql}, r.id
    SQL
    query.squish
  end

  def self.existing_scope_sql
    # have to do this to get the binds interpolated. remove any ordering and just grab the ID
    RawTime.connection.unprepared_statement { RawTime.reorder(nil).select('id').to_sql }
  end

  def self.permitted_column_names
    RawTimeParameters.enriched_query
  end
end
