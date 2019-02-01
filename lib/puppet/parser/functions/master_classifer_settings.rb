module Puppet::Parser::Functions
  newfunction(:master_classifer_settings, type: :rvalue) do
    function_parseyaml([function_file([File.join(lookupvar('settings::confdir').to_s, 'classifier.yaml')])])
  end
end
