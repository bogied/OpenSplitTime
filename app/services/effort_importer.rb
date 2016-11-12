class EffortImporter
  extend ActiveModel::Naming

  attr_reader :errors, :effort_import_report, :effort_id_array, :effort_failure_array, :effort_importer

  def initialize(file_url, event, current_user_id)
    @errors = ActiveModel::Errors.new(self)
    @import_file = ImportFile.new(file_url)
    @event = event
    @current_user_id = current_user_id
    @sub_split_bitkey_hashes = event.sub_split_bitkey_hashes
    @effort_failure_array = []
    @effort_id_array = []
    @effort_schema = EffortSchema.new(header_column_titles)
  end

  def effort_import
    unless column_count_matches
      self.effort_import_report = 'Column count does not match'
      return
    end
    start_offset_hash = {}
    final_split_hash = {}
    (effort_offset..spreadsheet.last_row).each do |i|
      row = spreadsheet.row(i)
      row_effort_data = prepare_row_effort_data(row[0..split_offset - 2])
      effort = create_effort(row_effort_data)
      if effort
        row_time_data = row[split_offset - 1..row.size - 1]
        row_time_data.unshift(0) if finish_times_only?
        creator = EffortSplitTimeCreator.new(row_time_data, effort, current_user_id, event)
        start_offset, final_split = create_split_times(row, effort.id)
        start_offset_hash[effort.id] = start_offset if start_offset
        final_split_hash[effort.id] = final_split
        effort_id_array << effort.id
      else
        effort_failure_array << row
      end
    end
    BulkUpdateService.bulk_update_start_offset(start_offset_hash)
    BulkUpdateService.bulk_update_dropped(final_split_hash)
    # Set data status on only those efforts that were successfully created
    DataStatusService.set_data_status(event.efforts.find(effort_id_array))
    self.effort_import_report = EventReconcileService.auto_reconcile_efforts(event)
  end

  def effort_import_without_times
    self.import_without_times = true
    (effort_offset..spreadsheet.last_row).each do |i|
      row = spreadsheet.row(i)
      row_effort_data = prepare_row_effort_data(row)
      effort = create_effort(row_effort_data)
      if effort
        effort_id_array << effort.id
      else
        effort_failure_array << row
      end
    end
    self.effort_import_report = EventReconcileService.auto_reconcile_efforts(event)
  end

  # The following three methods are required for ActiveModel error reporting

  def read_attribute_for_validation(attr)
    send(attr)
  end

  def EffortImporter.human_attribute_name(attr)
    attr
  end

  def EffortImporter.lookup_ancestors
    [self]
  end

  private

  attr_accessor :import_file, :auto_matched_count, :participants_created_count, :unreconciled_efforts_count,
                :effort_schema, :import_without_times

  attr_reader :event, :current_user_id, :sub_split_bitkey_hashes

  attr_writer :effort_import_report, :effort_id_array, :effort_failure_array, :effort_importer

  delegate :spreadsheet, :header1, :header2, :split_offset, :effort_offset, :split_title_array, :finish_times_only?,
           :header1_downcase, to: :import_file

  def column_count_matches
    if (event_sub_split_count == 2) && ((split_title_array.size < 1) | (split_title_array.size > 2))
      errors.add(:effort_importer, "Your import file contains #{split_title_array.size} split time columns, but this event expects only a finish time column with an optional start time column. Please check your import file or create, remove, or associate splits as needed.")
      false
    elsif (event_sub_split_count > 2) && (split_title_array.size != event_sub_split_count)
      errors.add(:effort_importer, "Your import file contains #{split_title_array.size} split time columns, but this event expects #{event_sub_split_count} columns. Please check your import file or create, remove, or associate splits as needed.")
      false
    else
      true
    end
  end

  def create_effort(row_effort_data)
    effort = event.efforts.new
    row_hash(row_effort_data).each { |attribute, data| effort.assign_attributes({attribute => data}) }
    effort.concealed = true if event.concealed?
    effort.save ? effort : nil
  end

  def row_hash(row_effort_data)
    effort_schema.zip(row_effort_data).select { |title, data| title && data }.to_h
  end

  # Creates split_times for each valid time entry in the provided row
  # and returns the start_offset (if the first time entry is non-zero)
  # and the dropped_split_id (if there is no valid finish time)

  def create_split_times(row, effort_id)
    row_time_data = row[split_offset - 1..row.size - 1]
    row_time_data.unshift(0) if finish_times_only?
    return [nil, nil] if event_sub_split_count != row_time_data.size
    return [nil, nil] if row_time_data.compact.empty?
    dropped_split_pointer = start_offset = nil
    finish_bitkey_hash = sub_split_bitkey_hashes.last

    SplitTime.bulk_insert(:effort_id, :split_id, :sub_split_bitkey,
                          :time_from_start, :created_at, :updated_at,
                          :created_by, :updated_by) do |worker|
      (0...sub_split_bitkey_hashes.count).each do |i|
        bitkey_hash = sub_split_bitkey_hashes[i]
        split_id = bitkey_hash.keys.first
        sub_split_bitkey = bitkey_hash.values.first
        working_time = row_time_data[i]

        # If this is the first (start) column, set start_offset
        # from non-zero start split time and reset start split time to zero

        if i == 0
          start_offset = working_time || 0
          working_time = 0
        end

        seconds = convert_time_to_standard(working_time)

        # If no valid time is present, go to next without creating a split_time
        # and without updating the dropped_split_pointer

        next if seconds.nil?
        worker.add(effort_id: effort_id,
                   split_id: split_id,
                   sub_split_bitkey: sub_split_bitkey,
                   time_from_start: seconds,
                   created_by: current_user_id,
                   updated_by: current_user_id)
        dropped_split_pointer = (bitkey_hash == finish_bitkey_hash) ? nil : split_id
      end
    end
    [start_offset, dropped_split_pointer]
  end

  def prepare_row_effort_data(row_effort_data)
    EffortImportDataPreparer.new(row_effort_data, effort_schema.to_a).output_row
  end

  def convert_time_to_standard(working_time)
    return nil if working_time.blank?
    working_time = working_time.to_datetime if working_time.instance_of?(Date)
    working_time = datetime_to_seconds(working_time) if working_time.acts_like?(:time)
    if working_time.try(:to_f)
      working_time
    else
      errors.add(:effort_importer, "Invalid split time data for #{effort.last_name}. #{errors.full_messages}.")
    end
  end

  def datetime_to_seconds(value)
    start_time = value.year < 1910 ? '1899-12-30'.to_datetime : event.start_time
    TimeDifference.between(value, start_time).in_seconds
  end

  def event_sub_split_count
    sub_split_bitkey_hashes.count
  end

  def header_column_titles
    import_without_times ? header1 : header1[0..split_offset - 2]
  end

end