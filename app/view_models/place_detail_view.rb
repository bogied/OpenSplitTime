class PlaceDetailView

  attr_reader :effort, :event, :place_detail_rows
  delegate :full_name, :event_name, :participant, :bib_number, :combined_places, :finish_status,
           :gender, to: :effort

  PEER_PROXIMITY = 0.02

  def initialize(effort)
    @effort = effort
    @event = @effort.event
    @event_efforts = @event.efforts.to_a
    @indexed_start_offsets = Hash[@event_efforts.map { |e| [e.id, e.start_offset] }]
    @ordered_splits = @event.ordered_splits.to_a
    @event_split_times = @event.split_times.to_a
    set_day_and_time_attrs
    @indexed_split_times = @event_split_times.group_by(&:bitkey_hash)
    @split_place_columns = {}
    create_split_place_columns
    @place_detail_rows = []
    create_place_detail_rows
  end

  def efforts_passed(begin_bitkey_hash, end_bitkey_hash)
    begin_efforts_ahead = efforts_ahead(begin_bitkey_hash)
    end_efforts_ahead = efforts_ahead(end_bitkey_hash)
    return nil if begin_efforts_ahead.nil? || end_efforts_ahead.nil?
    ids = begin_efforts_ahead - end_efforts_ahead
    event_efforts.select { |effort| ids.include?(effort.id) }
  end

  def efforts_passed_by(begin_bitkey_hash, end_bitkey_hash)
    begin_efforts_ahead = efforts_ahead(begin_bitkey_hash)
    end_efforts_ahead = efforts_ahead(end_bitkey_hash)
    return nil if begin_efforts_ahead.nil? || end_efforts_ahead.nil?
    ids = end_efforts_ahead - begin_efforts_ahead
    event_efforts.select { |effort| ids.include?(effort.id) }
  end

  def efforts_together_in_aid(split)
    result = []
    begin_bitkey_hash = split.bitkey_hash_in
    end_bitkey_hash = split.bitkey_hash_out
    return [] unless begin_bitkey_hash && end_bitkey_hash
    segment_times = indexed_segment_times(begin_bitkey_hash, end_bitkey_hash)
    return [] unless segment_times[effort.id]
    subject_time_in = segment_times[effort.id][:in]
    subject_time_out = segment_times[effort.id][:out]
    return [] unless subject_time_in && subject_time_out
    event_efforts.each do |e|
      if times_overlap?(subject_time_in, subject_time_out, segment_times[e.id][:in], segment_times[e.id][:out])
        result << e
      end
    end
    result - [effort]
  end

  private

  attr_reader :ordered_splits, :event_efforts, :event_split_times, :indexed_split_times, :indexed_start_offsets, :split_place_columns

  def set_day_and_time_attrs
    event_start_time = event.start_time
    event_split_times.each { |split_time| split_time.day_and_time_attr =
        event_start_time + split_time.time_from_start + indexed_start_offsets[split_time.effort_id] }
  end

  def create_split_place_columns

    # Each column element contains a hash with
    # {effort_id: effort.id, day_and_time: datetime}, sorted by day_and_time

    bitkey_hashes = ordered_splits.map(&:sub_split_bitkey_hashes).flatten
    bitkey_hashes.each do |bitkey_hash|
      split_times = indexed_split_times[bitkey_hash]
      split_place_column = split_times.map { |split_time| {effort_id: split_time.effort_id, day_and_time: split_time.day_and_time_attr} }
      split_place_column.sort_by! { |row| row[:day_and_time] }
      split_place_columns[bitkey_hash] = split_place_column
    end
  end

  def create_place_detail_rows
    prior_bitkey_hash = ordered_splits.first.bitkey_hash_in
    ordered_splits.each do |split|
      next if split.start?
      place_detail_row = PlaceDetailRow.new(split,
                                            related_split_times(split),
                                            {split_place_in: split_place(split.bitkey_hash_in),
                                            split_place_out: split_place(split.bitkey_hash_out)},
                                            {passed_segment: efforts_passed(prior_bitkey_hash, split.bitkey_hash_in),
                                             passed_in_aid: efforts_passed(split.bitkey_hash_in, split.bitkey_hash_out),
                                             passed_by_segment: efforts_passed_by(prior_bitkey_hash, split.bitkey_hash_in),
                                             passed_by_in_aid: efforts_passed_by(split.bitkey_hash_in, split.bitkey_hash_out),
                                             together_in_aid: efforts_together_in_aid(split)})
      place_detail_rows << place_detail_row
      prior_bitkey_hash = place_detail_row.end_bitkey_hash
    end
  end

  def split_place(bitkey_hash)
    return nil unless bitkey_hash
    ordered_effort_ids = split_place_columns[bitkey_hash].map { |row| row[:effort_id] }
    ordered_effort_ids.index(effort.id) + 1
  end

  def efforts_ahead(bitkey_hash)
    return nil unless bitkey_hash
    ordered_effort_ids = split_place_columns[bitkey_hash].map { |row| row[:effort_id] }
    return [] if split_place(bitkey_hash) == 1
    ordered_effort_ids[0..(ordered_effort_ids.index(effort.id) - 1)]
  end

  def indexed_segment_times(begin_bitkey_hash, end_bitkey_hash)
    result = {}
    begin_split_times = indexed_split_times[begin_bitkey_hash].index_by(&:effort_id)
    end_split_times = indexed_split_times[end_bitkey_hash].index_by(&:effort_id)
    event_efforts.each do |effort|
      day_and_time_begin = begin_split_times[effort.id] ? begin_split_times[effort.id].day_and_time_attr : nil
      day_and_time_end = end_split_times[effort.id] ? end_split_times[effort.id].day_and_time_attr : nil
      result[effort.id] = {in: day_and_time_begin, out: day_and_time_end}
    end
    result
  end

  def times_overlap?(subject_time_start, subject_time_end, compare_time_start, compare_time_end)
    return false unless subject_time_start && subject_time_end && compare_time_start && compare_time_end
    (subject_time_start <= compare_time_end) && (subject_time_end >= compare_time_start)
  end

  def time_within?(subject_time_start, subject_time_end, compare_time)
    return false unless subject_time_start && subject_time_end && compare_time
    (subject_time_start <= compare_time) && (subject_time_end >= compare_time)
  end

  def related_split_times(split)
    split.sub_split_bitkey_hashes.collect { |key_hash| indexed_split_times[key_hash].index_by(&:effort_id)[effort.id] }
  end

  def effort_start_time
    event.start_time + effort.start_offset
  end

end