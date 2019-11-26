Rails.application.routes.draw do
  post "/callback", to: 'home#line_callback'
  post "/slack_callback", to: 'home#slack_callback'
end
