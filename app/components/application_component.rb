class ApplicationComponent < ViewComponent::Base

  private

  def icon(name, **options)
    helpers.icon(name, **options)
  end

  def current_user
    helpers.current_user
  end

  def number_with_delimiter(number)
    helpers.number_with_delimiter(number)
  end

  def time_ago_in_words(time)
    helpers.time_ago_in_words(time)
  end

  def link_to(*args, **options, &block)
    helpers.link_to(*args, **options, &block)
  end
end
