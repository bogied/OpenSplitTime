require 'rails_helper'

# t.integer  "event_id",                  null: false
# t.integer  "participant_id"
# t.string   "wave"
# t.integer  "bib_number"
# t.string   "city",           limit: 64
# t.string   "state_code",     limit: 64
# t.integer  "age"
# t.boolean  "dropped_split_id"
# t.string   "first_name"
# t.string   "last_name"
# t.integer  "gender"
# t.string   "country_code",   limit: 2
# t.date     "birthdate"
# t.integer  "data_status"
# t.integer  "start_offset"

RSpec.describe Effort, type: :model do
  it_behaves_like 'data_status_methods'
  it_behaves_like 'auditable'
  it { is_expected.to strip_attribute(:first_name).collapse_spaces }
  it { is_expected.to strip_attribute(:last_name).collapse_spaces }
  it { is_expected.to strip_attribute(:state_code).collapse_spaces }
  it { is_expected.to strip_attribute(:country_code).collapse_spaces }

  describe 'validations' do
    let(:course) { Course.create!(name: 'Test Course') }
    let(:event) { Event.create!(course: course, name: 'Test Event', start_time: '2012-08-08 05:00:00', laps_required: 1) }
    let(:location1) { Location.create!(name: 'Mountain Town', elevation: 2400, latitude: 40.1, longitude: -105) }
    let(:location2) { Location.create!(name: 'Mountain Hideout', elevation: 2900, latitude: 40.3, longitude: -105.05) }
    let(:participant) { Participant.create!(first_name: 'Joe', last_name: 'Hardman',
                                            gender: 'male', birthdate: '1989-12-15',
                                            city: 'Boulder', state_code: 'CO', country_code: 'US') }

    it 'is valid when created with an event_id, first_name, last_name, and gender' do
      Effort.create!(event: event, first_name: 'David', last_name: 'Goliath', gender: 'male')

      expect(Effort.all.count).to(equal(1))
      expect(Effort.first.event).to eq(event)
      expect(Effort.first.last_name).to eq('Goliath')
    end

    it 'is invalid without an event_id' do
      effort = Effort.new(event: nil, first_name: 'David', last_name: 'Goliath', gender: 'male')
      expect(effort).not_to be_valid
      expect(effort.errors[:event_id]).to include("can't be blank")
    end

    it 'is invalid without a first_name' do
      effort = Effort.new(event: event, first_name: nil, last_name: 'Appleseed', gender: 'male')
      expect(effort).not_to be_valid
      expect(effort.errors[:first_name]).to include("can't be blank")
    end

    it 'is invalid without a last_name' do
      effort = Effort.new(first_name: 'Johnny', last_name: nil, gender: 'male')
      expect(effort).not_to be_valid
      expect(effort.errors[:last_name]).to include("can't be blank")
    end

    it 'is invalid without a gender' do
      effort = Effort.new(first_name: 'Johnny', last_name: 'Appleseed', gender: nil)
      expect(effort).not_to be_valid
      expect(effort.errors[:gender]).to include("can't be blank")
    end

    it 'does not permit more than one effort by a participant in a given event' do
      Effort.create!(event: event, first_name: 'David', last_name: 'Goliath', gender: 'male',
                     participant: participant)
      effort = Effort.new(event: event, first_name: 'David', last_name: 'Goliath', gender: 'male',
                          participant: participant)
      expect(effort).not_to be_valid
      expect(effort.errors[:participant_id]).to include('has already been taken')
    end

    it 'permits more than one effort in a given event with unassigned participants' do
      Effort.create!(event: event, first_name: 'David', last_name: 'Goliath', gender: 'male',
                     participant: nil)
      effort = Effort.new(event: event, first_name: 'Betty', last_name: 'Boop', gender: 'female',
                          participant: nil)
      expect(effort).to be_valid
    end

    it 'does not permit duplicate bib_numbers within a given event' do
      Effort.create!(event: event, first_name: 'David', last_name: 'Goliath', gender: 'male', bib_number: 20)
      effort = Effort.new(event: event, participant_id: 2, bib_number: 20)
      expect(effort).not_to be_valid
      expect(effort.errors[:bib_number]).to include('has already been taken')
    end
  end

  describe '#approximate_age_today' do
    it 'returns nil if age is not present' do
      effort = FactoryGirl.build(:effort)
      expect(effort.approximate_age_today).to be_nil
    end

    it 'calculates approximate age at the current time based on age at time of effort' do
      age = 40
      event_start_time = DateTime.new(2010, 1, 1, 0, 0, 0)
      years_since_effort = Time.now.year - event_start_time.year
      effort = FactoryGirl.build(:effort, age: age)
      expect(effort).to receive(:event_start_time).and_return(event_start_time)
      expect(effort.approximate_age_today).to eq(age + years_since_effort)
    end

    it 'functions properly for future events' do
      age = 40
      event_start_time = DateTime.new(2030, 1, 1, 0, 0, 0)
      years_since_effort = Time.now.year - event_start_time.year
      effort = FactoryGirl.build(:effort, age: age)
      expect(effort).to receive(:event_start_time).and_return(event_start_time)
      expect(effort.approximate_age_today).to eq(age + years_since_effort)
    end
  end

  describe '#time_in_aid' do
    it 'returns nil when the split has no split_times' do
      split_times = SplitTime.none
      effort = Effort.new(first_name: 'Joe', last_name: 'Tester', gender: 'male')
      split = FactoryGirl.build(:split)
      expect(effort).to receive(:ordered_split_times).and_return(split_times)
      expect(effort.time_in_aid(split)).to be_nil
    end

    it 'returns nil when the split has only one split_time' do
      split_times = FactoryGirl.build_stubbed_list(:split_times_in_only, 4)
      effort = Effort.new(first_name: 'Joe', last_name: 'Tester', gender: 'male')
      split = FactoryGirl.build(:split, id: 202)
      matching_split_times = split_times.select { |split_time| split_time.split_id == split.id }
      expect(matching_split_times.count).to eq(1)
      expect(effort).to receive(:ordered_split_times).and_return(matching_split_times)
      expect(effort.time_in_aid(split)).to be_nil
    end

    it 'returns the difference between in and out times when the split has in and out split_times' do
      split_times = FactoryGirl.build_stubbed_list(:split_times_in_out, 4)
      effort = Effort.new(first_name: 'Joe', last_name: 'Tester', gender: 'male')
      split = FactoryGirl.build(:split, id: 102)
      matching_split_times = split_times.select { |split_time| split_time.split_id == split.id }
      expect(matching_split_times.count).to eq(2)
      expect(effort).to receive(:ordered_split_times).and_return(matching_split_times)
      expect(effort.time_in_aid(split)).to eq(600)
    end
  end

  describe '#total_time_in_aid' do
    it 'returns zero when the event has no splits' do
      split_times = []
      effort = FactoryGirl.build(:effort)
      expect(effort).to receive(:ordered_split_times).and_return(split_times)
      expect(effort.total_time_in_aid).to eq(0)
    end

    it 'returns zero when the event has only "in" splits' do
      split_times = FactoryGirl.build_stubbed_list(:split_times_in_only, 12)
      effort = FactoryGirl.build(:effort)
      expect(effort).to receive(:ordered_split_times).and_return(split_times)
      expect(effort.total_time_in_aid).to eq(0)
    end

    it 'correctly calculates time in aid based on times in and out of splits' do
      split_times = FactoryGirl.build_stubbed_list(:split_times_in_out, 12)
      effort = FactoryGirl.build(:effort)
      expect(effort).to receive(:ordered_split_times).and_return(split_times)
      expect(effort.total_time_in_aid).to eq(3000)
    end
  end

  describe '#day_and_time' do
    it 'returns a day and time based on the effort start plus the provided time_from_start' do
      event = FactoryGirl.build_stubbed(:event, start_time: '2017-03-15 06:00:00')
      effort = FactoryGirl.build_stubbed(:effort, start_offset: 0)
      allow(effort).to receive(:event).and_return(event)
      time_from_start = 3.hours
      expect(effort.day_and_time(time_from_start)).to eq(effort.start_time + 3.hours)
    end
  end

  describe '#start_time=' do
    it 'sets start_offset to the difference between the provided parameter and event start time' do
      event = FactoryGirl.build_stubbed(:event, start_time: '2017-03-15 06:00:00')
      effort = FactoryGirl.build_stubbed(:effort, start_offset: 0)
      allow(effort).to receive(:event).and_return(event)
      effort.start_time = event.start_time + 3.hours
      expect(effort.start_offset).to eq(3.hours)
    end

    it 'works properly when the effort starts before the event' do
      event = FactoryGirl.build_stubbed(:event, start_time: '2017-03-15 06:00:00')
      effort = FactoryGirl.build_stubbed(:effort, start_offset: 0)
      allow(effort).to receive(:event).and_return(event)
      effort.start_time = event.start_time - 3.hours
      expect(effort.start_offset).to eq(-3.hours)
    end

    it 'works properly when the offset is large' do
      event = FactoryGirl.build_stubbed(:event, start_time: '2017-03-15 06:00:00')
      effort = FactoryGirl.build_stubbed(:effort, start_offset: 0)
      allow(effort).to receive(:event).and_return(event)
      effort.start_time = event.start_time + (24.hours * 365)
      expect(effort.start_offset).to eq(24.hours * 365)
    end
  end

  describe '#dropped_lap_split_key' do
    it 'returns a LapSplitKey using dropped_lap and dropped_split_id' do
      effort = FactoryGirl.build_stubbed(:effort, dropped_lap: 1, dropped_split_id: 101)
      expect(effort.dropped_key).to eq(LapSplitKey.new(1, 101))
    end

    it 'returns nil if dropped_split_id is not present' do
      effort = FactoryGirl.build_stubbed(:effort, dropped_lap: 1, dropped_split_id: nil)
      expect(effort.dropped_key).to be_nil
    end

    it 'returns nil if dropped_lap is not present' do
      effort = FactoryGirl.build_stubbed(:effort, dropped_lap: nil, dropped_split_id: 101)
      expect(effort.dropped_key).to be_nil
    end
  end

  describe '#dropped_lap_split_key=' do
    it 'sets dropped_lap and dropped_split_id to the attributes of the provided LapSplitKey' do
      lap_split_key = LapSplitKey.new(1, 101)
      effort = FactoryGirl.build_stubbed(:effort, dropped_lap: nil, dropped_split_id: nil)
      effort.dropped_lap_split_key = lap_split_key
      expect(effort.dropped_lap).to eq(1)
      expect(effort.dropped_split_id).to eq(101)
    end

    it 'sets dropped_lap and dropped_split_id to nil if the provided LapSplitKey has nil attributes' do
      lap_split_key = LapSplitKey.new(nil, nil)
      effort = FactoryGirl.build_stubbed(:effort, dropped_lap: 1, dropped_split_id: 101)
      effort.dropped_lap_split_key = lap_split_key
      expect(effort.dropped_lap).to eq(nil)
      expect(effort.dropped_split_id).to eq(nil)
    end

    it 'sets dropped_lap and dropped_split_id to nil if provided parameter is nil' do
      effort = FactoryGirl.build_stubbed(:effort, dropped_lap: 1, dropped_split_id: 101)
      effort.dropped_lap_split_key = nil
      expect(effort.dropped_lap).to eq(nil)
      expect(effort.dropped_split_id).to eq(nil)
    end
  end

  describe '#drop!' do
    it 'sets dropped_lap and dropped_split_id to the provided lap_split_key and saves the effort' do
      effort = FactoryGirl.create(:effort, dropped_lap: nil, dropped_split_id: nil)
      lap_split_key = LapSplitKey.new(1, 101)
      effort.drop!(lap_split_key)
      effort = Effort.last
      expect(effort.dropped_lap).to eq(1)
      expect(effort.dropped_split_id).to eq(101)
    end

    it 'sets dropped_lap and dropped_split_id to nil and saves the effort if the provided parameter is nil' do
      effort = FactoryGirl.create(:effort, dropped_lap: 1, dropped_split_id: 101)
      lap_split_key = nil
      effort.drop!(lap_split_key)
      effort = Effort.last
      expect(effort.dropped_lap).to be_nil
      expect(effort.dropped_split_id).to be_nil
    end
  end

  describe '#undrop!' do
    it 'sets dropped_lap and dropped_split_id to nil and saves the effort' do
      effort = FactoryGirl.create(:effort, dropped_lap: 1, dropped_split_id: 101)
      effort.undrop!
      effort = Effort.last
      expect(effort.dropped_lap).to be_nil
      expect(effort.dropped_split_id).to be_nil
    end
  end

  describe '#finished?' do
    context 'for an event with a fixed lap requirement' do
      let(:laps_required) { 2 }
      let(:test_event) { FactoryGirl.build_stubbed(:event_functional, laps_required: laps_required) }
      let(:test_effort) { test_event.efforts.first }
      let(:test_splits) { test_event.splits }
      let(:test_split_times) { test_effort.split_times }

      it 'returns true when laps_finished is at least equal to laps_required' do
        effort = test_effort
        split_times = test_effort.split_times
        allow(effort).to receive(:ordered_split_times).and_return(split_times)
        expect(effort.laps_required).to eq(laps_required)
        expect(effort.laps_finished).to eq(laps_required)
        expect(effort.finished?).to eq(true)
      end

      it 'returns false when laps_finished is less than laps_required' do
        effort = test_effort
        split_times = test_effort.split_times[0..-2] # all but the last split_time
        allow(effort).to receive(:ordered_split_times).and_return(split_times)
        expect(effort.laps_required).to eq(laps_required)
        expect(effort.laps_finished).to eq(laps_required - 1)
        expect(effort.finished?).to eq(false)
      end

      it 'returns false when the effort is not started' do
        effort = test_effort
        split_times = []
        allow(effort).to receive(:ordered_split_times).and_return(split_times)
        expect(effort.laps_required).to eq(laps_required)
        expect(effort.laps_finished).to eq(0)
        expect(effort.finished?).to eq(false)
      end
    end

    context 'for an event with unlimited laps' do
      let(:laps_required) { 0 }
      let(:test_event) { FactoryGirl.build_stubbed(:event_functional, laps_required: laps_required) }
      let(:test_effort) { test_event.efforts.first }
      let(:test_splits) { test_event.splits }
      let(:test_split_times) { test_effort.split_times }

      it 'returns false when no split_time has stopped_here = true' do
        effort = test_effort
        expect(effort.split_times.none?(&:stopped_here)).to eq(true)
        expect(effort.finished?).to eq(false)
      end

      it 'returns true when any split_time has stopped_here = true' do
        effort = test_effort
        effort.split_times.last.stopped_here = true
        expect(effort.finished?).to eq(true)
      end
    end
  end

  describe '#dropped?' do
    context 'for an event with a fixed lap requirement' do
      let(:laps_required) { 1 }
      let(:test_event) { FactoryGirl.build_stubbed(:event_functional, laps_required: laps_required) }
      let(:test_effort) { test_event.efforts.first }
      let(:test_split_times) { test_effort.split_times }
      let(:incomplete_split_times) { test_split_times.first(2) }

      it 'returns true when a split_time is stopped_here and laps_required are not completed' do
        effort = test_effort
        allow(effort).to receive(:ordered_split_times).and_return(incomplete_split_times)
        incomplete_split_times.last.stopped_here = true
        expect(effort.dropped?).to eq(true)
      end

      it 'returns false when no split_time is stopped_here although laps_required are not completed' do
        effort = test_effort
        allow(effort).to receive(:ordered_split_times).and_return(incomplete_split_times)
        expect(effort.ordered_split_times.none?(&:stopped_here)).to eq(true)
        expect(effort.dropped?).to eq(false)
      end
    end

    context 'for an event with unlimited laps' do
      let(:laps_required) { 0 }
      let(:test_event) { FactoryGirl.build_stubbed(:event_functional, laps_required: laps_required) }
      let(:test_effort) { test_event.efforts.first }
      let(:test_split_times) { test_effort.split_times }

      it 'returns false always, including when a split_time is stopped_here' do
        effort = test_effort
        effort.split_times.last.stopped_here = true
        expect(effort.dropped?).to eq(false)
      end

      it 'returns false always, including when no split_time is stopped_here' do
        effort = test_effort
        expect(effort.split_times.none?(&:stopped_here)).to eq(true)
        expect(effort.dropped?).to eq(false)
      end
    end
  end

  describe '#stopped?' do
    context 'for an event with a fixed lap requirement' do
      let(:laps_required) { 1 }
      let(:test_event) { FactoryGirl.build_stubbed(:event_functional, laps_required: laps_required) }
      let(:test_effort) { test_event.efforts.first }
      let(:test_split_times) { test_effort.split_times }
      let(:incomplete_split_times) { test_split_times.first(2) }

      it 'returns true when the effort is finished and the last split_time is stopped_here' do
        effort = test_effort
        effort.split_times.last.stopped_here = true
        expect(effort.stopped?).to eq(true)
      end

      it 'returns true when the effort is finished even if no split_time is stopped_here' do
        effort = test_effort
        split_times = test_effort.split_times
        allow(effort).to receive(:ordered_split_times).and_return(split_times)
        expect(effort.finished?).to eq(true)
        expect(effort.split_times.none?(&:stopped_here)).to eq(true)
        expect(effort.stopped?).to eq(true)
      end

      it 'returns true when the effort is not finished and any split_time is stopped_here' do
        effort = test_effort
        allow(effort).to receive(:ordered_split_times).and_return(incomplete_split_times)
        incomplete_split_times.last.stopped_here = true
        expect(effort.stopped?).to eq(true)
      end

      it 'returns false when the effort is not finished and no split_time is stopped_here' do
        effort = test_effort
        allow(effort).to receive(:ordered_split_times).and_return(incomplete_split_times)
        expect(incomplete_split_times.none?(&:stopped_here)).to eq(true)
        expect(effort.stopped?).to eq(false)
      end
    end

    context 'for an event with unlimited laps' do
      let(:laps_required) { 0 }
      let(:test_event) { FactoryGirl.build_stubbed(:event_functional, laps_required: laps_required) }
      let(:test_effort) { test_event.efforts.first }
      let(:test_split_times) { test_effort.split_times }
      let(:incomplete_split_times) { test_split_times.first(2) }

      it 'returns true when any split_time is stopped_here' do
        effort = test_effort
        effort.split_times.last.stopped_here = true
        expect(effort.stopped?).to eq(true)
      end

      it 'returns false when no split_times is stopped_here' do
        effort = test_effort
        expect(effort.split_times.none?(&:stopped_here)).to eq(true)
        expect(effort.stopped?).to eq(false)
      end
    end
  end
end