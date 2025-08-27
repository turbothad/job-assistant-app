class CreateJobListings < ActiveRecord::Migration[8.0]
  def change
    create_table :job_listings do |t|
      t.string :title
      t.string :company
      t.string :location
      t.string :salary_range
      t.text :description
      t.boolean :remote
      t.string :experience_level
      t.datetime :posted_at
      t.string :job_url

      t.timestamps
    end
  end
end
