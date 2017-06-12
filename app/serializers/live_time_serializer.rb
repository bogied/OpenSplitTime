class LiveTimeSerializer < BaseSerializer
  attributes :id, :event_id, :bib_number, :lap, :split_id, :bitkey, :absolute_time, :stopped_here,
             :with_pacer, :remarks, :batch, :source, :event_slug, :split_slug
  link(:self) { api_v1_live_time_path(object) }

  belongs_to :event
  belongs_to :split
end
