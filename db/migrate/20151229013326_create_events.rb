class CreateEvents < ActiveRecord::Migration
  def change
    create_table :events do |t|
      t.references :course, index: true, foreign_key: true, :null => false
      t.references :race, index: true, foreign_key: true
      t.string :name, :null => false, limit: 64
      t.date :start_date, :null => false

      t.timestamps null: false
      t.authorstamps :integer
    end
  end
end
