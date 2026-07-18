namespace :unforgettable do
  desc "Split legacy full name into first_name/last_name"
  task release_20260718171744: :environment do
    # After the rename migration, first_name holds the whole legacy name
    # (e.g. "Sarah Mitchell"). Split it so first_name is just the first word and
    # last_name is the rest. Keeping the remainder (rather than only the second
    # word) avoids dropping the tail of 3+ word names like "Mary Jane Watson".
    # Single-word names leave last_name nil, which the model treats as invalid
    # until the user supplies one. update_columns persists without firing that
    # validation or the create/update callbacks and broadcasts.
    scope = User.where(last_name: nil)
    total = scope.count

    puts "Splitting name into first_name/last_name for #{total} user(s)..."

    scope.find_each do |user|
      first, *rest = user.first_name.to_s.split
      user.update_columns(first_name: first, last_name: rest.join(" ").presence)
    end

    puts "Done."
  end
end
