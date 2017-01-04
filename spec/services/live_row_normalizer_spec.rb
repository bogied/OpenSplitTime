require 'rails_helper'
include ActionDispatch::TestProcess

RSpec.describe LiveRowNormalizer do
  let(:headers) { %w(bibNumber timeIn timeOut pacerIn pacerOut droppedHere) }

  describe '#initialize' do
    it 'creates a new object using an args hash containing a csv file row' do
      values = %w(9 6:54:00 7:06:00 TRUE TRUE FALSE)
      csv_row = CSV::Row.new(headers, values)
      expect { LiveRowNormalizer.normalize(csv_row) }.not_to raise_error
    end
  end

  describe '.normalize' do
    it 'assigns bib number values to a file_row hash' do
      values = %w(9 12:54:00 13:04:30 TRUE TRUE FALSE)
      csv_row = CSV::Row.new(headers, values)
      file_row = LiveRowNormalizer.normalize(csv_row)
      expect(file_row[:bibNumber]).to eq('9')
    end

    it 'assigns nil to bib number when not provided' do
      values = ['', '12:54:00', '13:04:30', 'T', 'T', 'T']
      csv_row = CSV::Row.new(headers, values)
      file_row = LiveRowNormalizer.normalize(csv_row)
      expect(file_row[:bibNumber]).to be_nil
    end

    it 'assigns time in and time out values to a file_row hash' do
      values = %w(9 12:54:00 13:04:30 TRUE TRUE FALSE)
      csv_row = CSV::Row.new(headers, values)
      file_row = LiveRowNormalizer.normalize(csv_row)
      expect(file_row[:timeIn]).to eq('12:54:00')
      expect(file_row[:timeOut]).to eq('13:04:30')
    end

    it 'assigns nil to time in value when time in is invalid' do
      values = %w(9 32:54:00 13:04:30 TRUE TRUE FALSE)
      csv_row = CSV::Row.new(headers, values)
      file_row = LiveRowNormalizer.normalize(csv_row)
      expect(file_row[:timeIn]).to be_nil
      expect(file_row[:timeOut]).to eq('13:04:30')
    end

    it 'assigns nil to time in value when time in is not provided' do
      values = ['9', '', '13:04:30', 'T', 'T', 'T']
      csv_row = CSV::Row.new(headers, values)
      file_row = LiveRowNormalizer.normalize(csv_row)
      expect(file_row[:timeIn]).to be_nil
      expect(file_row[:timeOut]).to eq('13:04:30')
    end

    it 'assigns nil to time out value when time out is invalid' do
      values = %w(9 12:54:00 33:04:30 TRUE TRUE FALSE)
      csv_row = CSV::Row.new(headers, values)
      file_row = LiveRowNormalizer.normalize(csv_row)
      expect(file_row[:timeIn]).to eq('12:54:00')
      expect(file_row[:timeOut]).to be_nil
    end

    it 'assigns nil to time out value when time out is not provided' do
      values = ['9', '12:54:00', '', 'T', 'T', 'T']
      csv_row = CSV::Row.new(headers, values)
      file_row = LiveRowNormalizer.normalize(csv_row)
      expect(file_row[:timeIn]).to eq('12:54:00')
      expect(file_row[:timeOut]).to be_nil
    end

    it 'assigns pacer in, pacer out, and dropped here values to a file_row hash' do
      values = %w(9 12:54:00 13:04:30 TRUE TRUE FALSE)
      csv_row = CSV::Row.new(headers, values)
      file_row = LiveRowNormalizer.normalize(csv_row)
      expect(file_row[:pacerIn]).to eq('true')
      expect(file_row[:pacerOut]).to eq('true')
      expect(file_row[:droppedHere]).to eq('false')
    end

    it 'assigns true to pacer in, pacer out, and dropped here values when first letter is "t"' do
      values = %w(9 12:54:00 13:04:30 T true Table)
      csv_row = CSV::Row.new(headers, values)
      file_row = LiveRowNormalizer.normalize(csv_row)
      expect(file_row[:pacerIn]).to eq('true')
      expect(file_row[:pacerOut]).to eq('true')
      expect(file_row[:droppedHere]).to eq('true')
    end

    it 'assigns true to pacer in, pacer out, and dropped here values when first letter is "y"' do
      values = %w(9 12:54:00 13:04:30 Y yes Yellow)
      csv_row = CSV::Row.new(headers, values)
      file_row = LiveRowNormalizer.normalize(csv_row)
      expect(file_row[:pacerIn]).to eq('true')
      expect(file_row[:pacerOut]).to eq('true')
      expect(file_row[:droppedHere]).to eq('true')
    end

    it 'assigns false to pacer in, pacer out, and dropped here values when first letter is "f"' do
      values = %w(9 12:54:00 13:04:30 F false Flavor)
      csv_row = CSV::Row.new(headers, values)
      file_row = LiveRowNormalizer.normalize(csv_row)
      expect(file_row[:pacerIn]).to eq('false')
      expect(file_row[:pacerOut]).to eq('false')
      expect(file_row[:droppedHere]).to eq('false')
    end

    it 'assigns false to pacer in, pacer out, and dropped here values when first letter is anything but "t" or "y"' do
      values = %w(9 12:54:00 13:04:30 No Possibly Maybe)
      csv_row = CSV::Row.new(headers, values)
      file_row = LiveRowNormalizer.normalize(csv_row)
      expect(file_row[:pacerIn]).to eq('false')
      expect(file_row[:pacerOut]).to eq('false')
      expect(file_row[:droppedHere]).to eq('false')
    end

    it 'assigns nil to pacer in, pacer out, and dropped here values when data are absent' do
      values = ['9', '12:54:00', '13:04:30', '', '', '']
      csv_row = CSV::Row.new(headers, values)
      file_row = LiveRowNormalizer.normalize(csv_row)
      expect(file_row[:pacerIn]).to be_nil
      expect(file_row[:pacerOut]).to be_nil
      expect(file_row[:droppedHere]).to be_nil
    end
  end
end