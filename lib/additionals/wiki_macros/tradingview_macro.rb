# frozen_string_literal: true

# see https://www.tradingview.com/widget/
module Additionals
  module WikiMacros
    module TradingviewMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Creates Tradingview chart

    Syntax:

      {{tradingview(options)}}

    Parameters:

      :param int width: default 640
      :param int height: default 480
      :param string symbol: default NASDAQ:AAPL
      :param string interval: default W
      :param string timezone: default Europe/Berlin
      :param string theme: default White
      :param int style: default 2
      :param string locale: default de
      :param string toolbar_bg: default #f1f3f6
      :param bool enable_publishing: default false
      :param bool allow_symbol_change: default true
      :param bool hideideasbutton: default true

    Examples:

    {{tradingview(symbol=NASDAQ:AMZN, locale=en)}} - Show chart with symbol `NASDAQ:AMZN` and use English locale
        DESCRIPTION

        macro :tradingview do |_obj, args|
          raise 'The correct usage is {{tradingview(options)}}' if args.empty?

          _args, options = extract_macro_options(args, :width, :height, :symbol, :interval, :timezone,
                                                 :theme, :style, :locale, :toolbar_bg, :enable_publishing,
                                                 :allow_symbol_change, :hideideasbutton)

          options[:width] = 640 if options[:width].blank?
          options[:height] = 480 if options[:height].blank?
          options[:symbol] = 'NASDAQ:AAPL' if options[:symbol].blank?
          options[:interval] = 'W' if options[:interval].blank?
          options[:timezone] = 'Europe/Berlin' if options[:timezone].blank?
          options[:theme] = 'White' if options[:theme].blank?
          options[:style] = 2 if options[:style].blank?
          options[:locale] = 'de' if options[:locale].blank?
          options[:toolbar_bg] = '#f1f3f6' if options[:toolbar_bg].blank?
          options[:enable_publishing] = false if options[:enable_publishing].blank?
          options[:allow_symbol_change] = true if options[:allow_symbol_change].blank?
          options[:hideideasbutton] = true if options[:hideideasbutton].blank?

          render partial: 'wiki/tradingview',
                 formats: [:html],
                 locals: { options: options }
        end
      end
    end
  end
end
