module FeatureFlagHelper
  def feature_enabled?(key, user = current_user, context = {})
    FeatureFlagService.instance.enabled?(key, user, context)
  end

  def feature_disabled?(key, user = current_user, context = {})
    !feature_enabled?(key, user, context)
  end

  def feature_percentage(key)
    FeatureFlagService.instance.rollout_percentage(key)
  end
end
