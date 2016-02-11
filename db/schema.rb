# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160131195951) do

  create_table "countries", force: :cascade do |t|
    t.string   "code",       limit: 2, null: false
    t.string   "name",                 null: false
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  create_table "courses", force: :cascade do |t|
    t.string   "name",       limit: 64, null: false
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
  end

  create_table "efforts", force: :cascade do |t|
    t.integer  "event_id",                  null: false
    t.integer  "participant_id",            null: false
    t.string   "wave"
    t.integer  "bib_number"
    t.string   "city",           limit: 64
    t.string   "state",          limit: 64
    t.integer  "country_id"
    t.integer  "age"
    t.datetime "start_time",                null: false
    t.boolean  "finished"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "efforts", ["country_id"], name: "index_efforts_on_country_id"
  add_index "efforts", ["event_id"], name: "index_efforts_on_event_id"
  add_index "efforts", ["participant_id"], name: "index_efforts_on_participant_id"

  create_table "events", force: :cascade do |t|
    t.integer  "course_id",             null: false
    t.integer  "race_id"
    t.string   "name",       limit: 64, null: false
    t.date     "start_date",            null: false
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
  end

  add_index "events", ["course_id"], name: "index_events_on_course_id"
  add_index "events", ["race_id"], name: "index_events_on_race_id"

  create_table "interests", force: :cascade do |t|
    t.integer  "user_id",                    null: false
    t.integer  "participant_id",             null: false
    t.integer  "kind",           default: 0, null: false
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end

  add_index "interests", ["participant_id"], name: "index_interests_on_participant_id"
  add_index "interests", ["user_id", "participant_id"], name: "index_interests_on_user_id_and_participant_id", unique: true
  add_index "interests", ["user_id"], name: "index_interests_on_user_id"

  create_table "locations", force: :cascade do |t|
    t.string   "name",       limit: 64, null: false
    t.integer  "elevation"
    t.decimal  "latitude"
    t.decimal  "longitude"
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
  end

  create_table "ownerships", force: :cascade do |t|
    t.integer  "user_id",    null: false
    t.integer  "race_id",    null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "ownerships", ["race_id"], name: "index_ownerships_on_race_id"
  add_index "ownerships", ["user_id", "race_id"], name: "index_ownerships_on_user_id_and_race_id", unique: true
  add_index "ownerships", ["user_id"], name: "index_ownerships_on_user_id"

  create_table "participants", force: :cascade do |t|
    t.string   "first_name", limit: 32, null: false
    t.string   "last_name",  limit: 64, null: false
    t.string   "gender",                null: false
    t.date     "birthdate"
    t.string   "city"
    t.string   "state"
    t.integer  "country_id"
    t.string   "email"
    t.string   "phone"
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
  end

  add_index "participants", ["country_id"], name: "index_participants_on_country_id"

  create_table "races", force: :cascade do |t|
    t.string   "name",       limit: 64, null: false
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
  end

  create_table "split_times", force: :cascade do |t|
    t.integer  "effort_id",       null: false
    t.integer  "split_id",        null: false
    t.float    "time_from_start", null: false
    t.integer  "data_status"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  add_index "split_times", ["effort_id"], name: "index_split_times_on_effort_id"
  add_index "split_times", ["split_id"], name: "index_split_times_on_split_id"

  create_table "splits", force: :cascade do |t|
    t.integer  "course_id",                                   null: false
    t.integer  "location_id",                                 null: false
    t.string   "name",                 limit: 64,             null: false
    t.integer  "distance_from_start",                         null: false
    t.integer  "sub_order",                       default: 0, null: false
    t.integer  "vert_gain_from_start"
    t.integer  "vert_loss_from_start"
    t.integer  "kind",                                        null: false
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
  end

  add_index "splits", ["course_id"], name: "index_splits_on_course_id"
  add_index "splits", ["location_id"], name: "index_splits_on_location_id"

  create_table "users", force: :cascade do |t|
    t.integer  "participant_id"
    t.string   "first_name",             limit: 32,              null: false
    t.string   "last_name",              limit: 64,              null: false
    t.integer  "role"
    t.string   "provider"
    t.string   "uid"
    t.string   "email",                             default: "", null: false
    t.string   "encrypted_password",                default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                     default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
    t.datetime "created_at",                                     null: false
    t.datetime "updated_at",                                     null: false
  end

  add_index "users", ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
  add_index "users", ["email"], name: "index_users_on_email", unique: true
  add_index "users", ["participant_id"], name: "index_users_on_participant_id"
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true

end