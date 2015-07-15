# :diners_us:
#   :rules:
#     - :length:
#       - 16
#       :prefixes:
#       - '54'
#       - '55'
CreditCardValidations.add_brand(:diners_us, {length: 16, prefixes: %w(54 55)}, {brand_name: 'Diners Club US'})