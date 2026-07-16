// GENERATED COUNTRY AND CURRENCY CATALOG FOR QUIK ERP.
// Keep this file data-only so customer forms and future document modules can reuse it.

class CustomerCountryOption {
  final String name;
  final String isoCode;
  final String callingCode;
  final String currencyCode;

  const CustomerCountryOption({required this.name, required this.isoCode, required this.callingCode, required this.currencyCode});

  String get flagEmoji => isoCode.length == 2
      ? isoCode.codeUnits.map((unit) => String.fromCharCode(unit + 127397)).join()
      : '🌐';

  String get administrativeAreaLabel {
    switch (isoCode) {
      case 'US': return 'State';
      case 'CA': return 'Province / Territory';
      case 'AU': return 'State / Territory';
      case 'AE': return 'Emirate';
      case 'JP': return 'Prefecture';
      case 'IN': return 'State / Union Territory';
      default: return 'State / Province / Region';
    }
  }

  String get postalCodeLabel {
    switch (isoCode) {
      case 'IN': return 'PIN Code';
      case 'US': return 'ZIP Code';
      case 'GB': return 'Postcode';
      case 'CA': return 'Postal Code';
      case 'AU': return 'Postcode';
      default: return 'Postal / ZIP Code';
    }
  }

  String get taxRegistrationLabel {
    switch (isoCode) {
      case 'IN': return 'GSTIN';
      case 'US': return 'Tax ID / EIN';
      case 'CA': return 'GST/HST Registration No.';
      case 'GB': return 'VAT Registration No.';
      case 'AE': return 'Tax Registration Number (TRN)';
      case 'SA': return 'VAT Registration No.';
      case 'SG': return 'GST Registration No.';
      case 'AU': return 'ABN / GST Registration';
      case 'NZ': return 'GST Number';
      case 'DE': case 'FR': case 'IT': case 'ES': case 'NL': case 'BE': case 'AT': case 'IE': case 'PT': case 'SE': case 'DK': case 'FI': case 'PL': case 'CZ': case 'HU': case 'RO': case 'BG': case 'GR': case 'LU': case 'SK': case 'SI': case 'HR': case 'CY': case 'MT': case 'EE': case 'LV': case 'LT': return 'VAT ID';
      default: return 'Tax Registration Number';
    }
  }

  String get businessRegistrationLabel {
    switch (isoCode) {
      case 'IN': return 'PAN';
      case 'US': return 'Company Registration / State ID';
      case 'GB': return 'Company Number';
      case 'CA': return 'Business Number';
      case 'AE': return 'Trade Licence Number';
      case 'SA': return 'Commercial Registration No.';
      case 'SG': return 'UEN';
      case 'AU': return 'ACN';
      case 'NZ': return 'NZBN';
      case 'CN': return 'Unified Social Credit Code';
      case 'JP': return 'Corporate Number';
      default: return 'Business Registration Number';
    }
  }

  String? validatePostalCode(String value) {
    final postalCode = value.trim();
    if (postalCode.isEmpty) return null;
    switch (isoCode) {
      case 'IN': if (!RegExp(r'^\d{6}$').hasMatch(postalCode)) return 'Enter a valid 6-digit PIN code'; break;
      case 'US': if (!RegExp(r'^\d{5}(?:-\d{4})?$').hasMatch(postalCode)) return 'Enter a valid ZIP code'; break;
      case 'CA': if (!RegExp(r'^[A-Za-z]\d[A-Za-z][ -]?\d[A-Za-z]\d$').hasMatch(postalCode)) return 'Enter a valid Canadian postal code'; break;
      case 'GB': if (!RegExp(r'^[A-Za-z]{1,2}\d[A-Za-z\d]? ?\d[A-Za-z]{2}$').hasMatch(postalCode)) return 'Enter a valid UK postcode'; break;
      case 'AU': if (!RegExp(r'^\d{4}$').hasMatch(postalCode)) return 'Enter a valid 4-digit postcode'; break;
      case 'SG': if (!RegExp(r'^\d{6}$').hasMatch(postalCode)) return 'Enter a valid 6-digit postal code'; break;
      case 'JP': if (!RegExp(r'^\d{3}-?\d{4}$').hasMatch(postalCode)) return 'Enter a valid Japanese postal code'; break;
      default: if (postalCode.length > 20) return 'Postal code is too long';
    }
    return null;
  }
}

class CustomerCurrencyOption {
  final String code;
  final String name;
  final String symbol;
  const CustomerCurrencyOption({required this.code, required this.name, required this.symbol});
}

class CustomerCountryCurrencyCatalog {
  const CustomerCountryCurrencyCatalog._();

  static const List<CustomerCountryOption> countries = [
    CustomerCountryOption(name: "Afghanistan", isoCode: "AF", callingCode: "+93", currencyCode: "AFN"),
    CustomerCountryOption(name: "Albania", isoCode: "AL", callingCode: "+355", currencyCode: "ALL"),
    CustomerCountryOption(name: "Algeria", isoCode: "DZ", callingCode: "+213", currencyCode: "DZD"),
    CustomerCountryOption(name: "American Samoa", isoCode: "AS", callingCode: "+1684", currencyCode: "USD"),
    CustomerCountryOption(name: "Andorra", isoCode: "AD", callingCode: "", currencyCode: "EUR"),
    CustomerCountryOption(name: "Angola", isoCode: "AO", callingCode: "+244", currencyCode: "AOA"),
    CustomerCountryOption(name: "Anguilla", isoCode: "AI", callingCode: "+1264", currencyCode: "XCD"),
    CustomerCountryOption(name: "Antarctica", isoCode: "AQ", callingCode: "", currencyCode: "XXX"),
    CustomerCountryOption(name: "Antigua and Barbuda", isoCode: "AG", callingCode: "+1268", currencyCode: "XCD"),
    CustomerCountryOption(name: "Argentina", isoCode: "AR", callingCode: "+54", currencyCode: "ARS"),
    CustomerCountryOption(name: "Armenia", isoCode: "AM", callingCode: "+374", currencyCode: "AMD"),
    CustomerCountryOption(name: "Aruba", isoCode: "AW", callingCode: "+297", currencyCode: "AWG"),
    CustomerCountryOption(name: "Australia", isoCode: "AU", callingCode: "+61", currencyCode: "AUD"),
    CustomerCountryOption(name: "Austria", isoCode: "AT", callingCode: "+43", currencyCode: "EUR"),
    CustomerCountryOption(name: "Azerbaijan", isoCode: "AZ", callingCode: "+994", currencyCode: "AZN"),
    CustomerCountryOption(name: "Bahamas", isoCode: "BS", callingCode: "+1242", currencyCode: "BSD"),
    CustomerCountryOption(name: "Bahrain", isoCode: "BH", callingCode: "+973", currencyCode: "BHD"),
    CustomerCountryOption(name: "Bangladesh", isoCode: "BD", callingCode: "+880", currencyCode: "BDT"),
    CustomerCountryOption(name: "Barbados", isoCode: "BB", callingCode: "+1246", currencyCode: "BBD"),
    CustomerCountryOption(name: "Belarus", isoCode: "BY", callingCode: "+375", currencyCode: "BYN"),
    CustomerCountryOption(name: "Belgium", isoCode: "BE", callingCode: "+32", currencyCode: "EUR"),
    CustomerCountryOption(name: "Belize", isoCode: "BZ", callingCode: "+501", currencyCode: "BZD"),
    CustomerCountryOption(name: "Benin", isoCode: "BJ", callingCode: "+229", currencyCode: "XOF"),
    CustomerCountryOption(name: "Bermuda", isoCode: "BM", callingCode: "+1441", currencyCode: "BMD"),
    CustomerCountryOption(name: "Bhutan", isoCode: "BT", callingCode: "+975", currencyCode: "INR"),
    CustomerCountryOption(name: "Bolivia", isoCode: "BO", callingCode: "+591", currencyCode: "BOB"),
    CustomerCountryOption(name: "Bonaire, Sint Eustatius and Saba", isoCode: "BQ", callingCode: "", currencyCode: "USD"),
    CustomerCountryOption(name: "Bosnia and Herzegovina", isoCode: "BA", callingCode: "+387", currencyCode: "BAM"),
    CustomerCountryOption(name: "Botswana", isoCode: "BW", callingCode: "+267", currencyCode: "BWP"),
    CustomerCountryOption(name: "Bouvet Island", isoCode: "BV", callingCode: "", currencyCode: "NOK"),
    CustomerCountryOption(name: "Brazil", isoCode: "BR", callingCode: "+55", currencyCode: "BRL"),
    CustomerCountryOption(name: "British Indian Ocean Territory", isoCode: "IO", callingCode: "+246", currencyCode: "USD"),
    CustomerCountryOption(name: "Brunei", isoCode: "BN", callingCode: "+673", currencyCode: "BND"),
    CustomerCountryOption(name: "Bulgaria", isoCode: "BG", callingCode: "+359", currencyCode: "BGN"),
    CustomerCountryOption(name: "Burkina Faso", isoCode: "BF", callingCode: "+226", currencyCode: "XOF"),
    CustomerCountryOption(name: "Burundi", isoCode: "BI", callingCode: "+257", currencyCode: "BIF"),
    CustomerCountryOption(name: "Cabo Verde", isoCode: "CV", callingCode: "+238", currencyCode: "CVE"),
    CustomerCountryOption(name: "Cambodia", isoCode: "KH", callingCode: "+855", currencyCode: "KHR"),
    CustomerCountryOption(name: "Cameroon", isoCode: "CM", callingCode: "+237", currencyCode: "XAF"),
    CustomerCountryOption(name: "Canada", isoCode: "CA", callingCode: "+1", currencyCode: "CAD"),
    CustomerCountryOption(name: "Cayman Islands", isoCode: "KY", callingCode: "+1345", currencyCode: "KYD"),
    CustomerCountryOption(name: "Central African Republic", isoCode: "CF", callingCode: "+236", currencyCode: "XAF"),
    CustomerCountryOption(name: "Chad", isoCode: "TD", callingCode: "+235", currencyCode: "XAF"),
    CustomerCountryOption(name: "Chile", isoCode: "CL", callingCode: "+56", currencyCode: "CLP"),
    CustomerCountryOption(name: "China", isoCode: "CN", callingCode: "+86", currencyCode: "CNY"),
    CustomerCountryOption(name: "Christmas Island", isoCode: "CX", callingCode: "+61", currencyCode: "AUD"),
    CustomerCountryOption(name: "Cocos (Keeling) Islands", isoCode: "CC", callingCode: "+61", currencyCode: "AUD"),
    CustomerCountryOption(name: "Colombia", isoCode: "CO", callingCode: "+57", currencyCode: "COP"),
    CustomerCountryOption(name: "Comoros", isoCode: "KM", callingCode: "+269", currencyCode: "KMF"),
    CustomerCountryOption(name: "Congo", isoCode: "CG", callingCode: "+242", currencyCode: "XAF"),
    CustomerCountryOption(name: "Congo (DRC)", isoCode: "CD", callingCode: "+243", currencyCode: "CDF"),
    CustomerCountryOption(name: "Cook Islands", isoCode: "CK", callingCode: "+682", currencyCode: "NZD"),
    CustomerCountryOption(name: "Costa Rica", isoCode: "CR", callingCode: "+506", currencyCode: "CRC"),
    CustomerCountryOption(name: "Croatia", isoCode: "HR", callingCode: "+385", currencyCode: "EUR"),
    CustomerCountryOption(name: "Cuba", isoCode: "CU", callingCode: "+53", currencyCode: "CUP"),
    CustomerCountryOption(name: "Curaçao", isoCode: "CW", callingCode: "", currencyCode: "XCG"),
    CustomerCountryOption(name: "Cyprus", isoCode: "CY", callingCode: "+357", currencyCode: "EUR"),
    CustomerCountryOption(name: "Czechia", isoCode: "CZ", callingCode: "+420", currencyCode: "CZK"),
    CustomerCountryOption(name: "Côte d’Ivoire", isoCode: "CI", callingCode: "+225", currencyCode: "XOF"),
    CustomerCountryOption(name: "Denmark", isoCode: "DK", callingCode: "+45", currencyCode: "DKK"),
    CustomerCountryOption(name: "Djibouti", isoCode: "DJ", callingCode: "+253", currencyCode: "DJF"),
    CustomerCountryOption(name: "Dominica", isoCode: "DM", callingCode: "+1767", currencyCode: "XCD"),
    CustomerCountryOption(name: "Dominican Republic", isoCode: "DO", callingCode: "+1809", currencyCode: "DOP"),
    CustomerCountryOption(name: "Ecuador", isoCode: "EC", callingCode: "+593", currencyCode: "USD"),
    CustomerCountryOption(name: "Egypt", isoCode: "EG", callingCode: "+20", currencyCode: "EGP"),
    CustomerCountryOption(name: "El Salvador", isoCode: "SV", callingCode: "+503", currencyCode: "USD"),
    CustomerCountryOption(name: "Equatorial Guinea", isoCode: "GQ", callingCode: "+240", currencyCode: "XAF"),
    CustomerCountryOption(name: "Eritrea", isoCode: "ER", callingCode: "+291", currencyCode: "ERN"),
    CustomerCountryOption(name: "Estonia", isoCode: "EE", callingCode: "+372", currencyCode: "EUR"),
    CustomerCountryOption(name: "Eswatini", isoCode: "SZ", callingCode: "+268", currencyCode: "SZL"),
    CustomerCountryOption(name: "Ethiopia", isoCode: "ET", callingCode: "+251", currencyCode: "ETB"),
    CustomerCountryOption(name: "Falkland Islands (Malvinas)", isoCode: "FK", callingCode: "+500", currencyCode: "FKP"),
    CustomerCountryOption(name: "Faroe Islands", isoCode: "FO", callingCode: "+298", currencyCode: "DKK"),
    CustomerCountryOption(name: "Fiji", isoCode: "FJ", callingCode: "+679", currencyCode: "FJD"),
    CustomerCountryOption(name: "Finland", isoCode: "FI", callingCode: "+358", currencyCode: "EUR"),
    CustomerCountryOption(name: "France", isoCode: "FR", callingCode: "+33", currencyCode: "EUR"),
    CustomerCountryOption(name: "French Guiana", isoCode: "GF", callingCode: "+594", currencyCode: "EUR"),
    CustomerCountryOption(name: "French Polynesia", isoCode: "PF", callingCode: "+689", currencyCode: "XPF"),
    CustomerCountryOption(name: "French Southern Territories", isoCode: "TF", callingCode: "", currencyCode: "EUR"),
    CustomerCountryOption(name: "Gabon", isoCode: "GA", callingCode: "+241", currencyCode: "XAF"),
    CustomerCountryOption(name: "Gambia", isoCode: "GM", callingCode: "+220", currencyCode: "GMD"),
    CustomerCountryOption(name: "Georgia", isoCode: "GE", callingCode: "+995", currencyCode: "GEL"),
    CustomerCountryOption(name: "Germany", isoCode: "DE", callingCode: "+49", currencyCode: "EUR"),
    CustomerCountryOption(name: "Ghana", isoCode: "GH", callingCode: "+233", currencyCode: "GHS"),
    CustomerCountryOption(name: "Gibraltar", isoCode: "GI", callingCode: "+350", currencyCode: "GIP"),
    CustomerCountryOption(name: "Greece", isoCode: "GR", callingCode: "+30", currencyCode: "EUR"),
    CustomerCountryOption(name: "Greenland", isoCode: "GL", callingCode: "+299", currencyCode: "DKK"),
    CustomerCountryOption(name: "Grenada", isoCode: "GD", callingCode: "+1473", currencyCode: "XCD"),
    CustomerCountryOption(name: "Guadeloupe", isoCode: "GP", callingCode: "+590", currencyCode: "EUR"),
    CustomerCountryOption(name: "Guam", isoCode: "GU", callingCode: "+1671", currencyCode: "USD"),
    CustomerCountryOption(name: "Guatemala", isoCode: "GT", callingCode: "+502", currencyCode: "GTQ"),
    CustomerCountryOption(name: "Guernsey", isoCode: "GG", callingCode: "+44", currencyCode: "GBP"),
    CustomerCountryOption(name: "Guinea", isoCode: "GN", callingCode: "+224", currencyCode: "GNF"),
    CustomerCountryOption(name: "Guinea-Bissau", isoCode: "GW", callingCode: "+245", currencyCode: "XOF"),
    CustomerCountryOption(name: "Guyana", isoCode: "GY", callingCode: "+592", currencyCode: "GYD"),
    CustomerCountryOption(name: "Haiti", isoCode: "HT", callingCode: "+509", currencyCode: "HTG"),
    CustomerCountryOption(name: "Heard Island and McDonald Islands", isoCode: "HM", callingCode: "", currencyCode: "AUD"),
    CustomerCountryOption(name: "Honduras", isoCode: "HN", callingCode: "+504", currencyCode: "HNL"),
    CustomerCountryOption(name: "Hong Kong", isoCode: "HK", callingCode: "+852", currencyCode: "HKD"),
    CustomerCountryOption(name: "Hungary", isoCode: "HU", callingCode: "+36", currencyCode: "HUF"),
    CustomerCountryOption(name: "Iceland", isoCode: "IS", callingCode: "+354", currencyCode: "ISK"),
    CustomerCountryOption(name: "India", isoCode: "IN", callingCode: "+91", currencyCode: "INR"),
    CustomerCountryOption(name: "Indonesia", isoCode: "ID", callingCode: "+62", currencyCode: "IDR"),
    CustomerCountryOption(name: "Iran", isoCode: "IR", callingCode: "+98", currencyCode: "IRR"),
    CustomerCountryOption(name: "Iraq", isoCode: "IQ", callingCode: "+964", currencyCode: "IQD"),
    CustomerCountryOption(name: "Ireland", isoCode: "IE", callingCode: "+353", currencyCode: "EUR"),
    CustomerCountryOption(name: "Isle of Man", isoCode: "IM", callingCode: "+44", currencyCode: "GBP"),
    CustomerCountryOption(name: "Israel", isoCode: "IL", callingCode: "+972", currencyCode: "ILS"),
    CustomerCountryOption(name: "Italy", isoCode: "IT", callingCode: "+39", currencyCode: "EUR"),
    CustomerCountryOption(name: "Jamaica", isoCode: "JM", callingCode: "+1876", currencyCode: "JMD"),
    CustomerCountryOption(name: "Japan", isoCode: "JP", callingCode: "+81", currencyCode: "JPY"),
    CustomerCountryOption(name: "Jersey", isoCode: "JE", callingCode: "+44", currencyCode: "GBP"),
    CustomerCountryOption(name: "Jordan", isoCode: "JO", callingCode: "+962", currencyCode: "JOD"),
    CustomerCountryOption(name: "Kazakhstan", isoCode: "KZ", callingCode: "+76", currencyCode: "KZT"),
    CustomerCountryOption(name: "Kenya", isoCode: "KE", callingCode: "+254", currencyCode: "KES"),
    CustomerCountryOption(name: "Kiribati", isoCode: "KI", callingCode: "+686", currencyCode: "AUD"),
    CustomerCountryOption(name: "Kuwait", isoCode: "KW", callingCode: "+965", currencyCode: "KWD"),
    CustomerCountryOption(name: "Kyrgyzstan", isoCode: "KG", callingCode: "+996", currencyCode: "KGS"),
    CustomerCountryOption(name: "Laos", isoCode: "LA", callingCode: "+856", currencyCode: "LAK"),
    CustomerCountryOption(name: "Latvia", isoCode: "LV", callingCode: "+371", currencyCode: "EUR"),
    CustomerCountryOption(name: "Lebanon", isoCode: "LB", callingCode: "+961", currencyCode: "LBP"),
    CustomerCountryOption(name: "Lesotho", isoCode: "LS", callingCode: "+266", currencyCode: "ZAR"),
    CustomerCountryOption(name: "Liberia", isoCode: "LR", callingCode: "+231", currencyCode: "LRD"),
    CustomerCountryOption(name: "Libya", isoCode: "LY", callingCode: "+218", currencyCode: "LYD"),
    CustomerCountryOption(name: "Liechtenstein", isoCode: "LI", callingCode: "+423", currencyCode: "CHF"),
    CustomerCountryOption(name: "Lithuania", isoCode: "LT", callingCode: "+370", currencyCode: "EUR"),
    CustomerCountryOption(name: "Luxembourg", isoCode: "LU", callingCode: "+352", currencyCode: "EUR"),
    CustomerCountryOption(name: "Macao", isoCode: "MO", callingCode: "+853", currencyCode: "MOP"),
    CustomerCountryOption(name: "Madagascar", isoCode: "MG", callingCode: "+261", currencyCode: "MGA"),
    CustomerCountryOption(name: "Malawi", isoCode: "MW", callingCode: "+265", currencyCode: "MWK"),
    CustomerCountryOption(name: "Malaysia", isoCode: "MY", callingCode: "+60", currencyCode: "MYR"),
    CustomerCountryOption(name: "Maldives", isoCode: "MV", callingCode: "+960", currencyCode: "MVR"),
    CustomerCountryOption(name: "Mali", isoCode: "ML", callingCode: "+223", currencyCode: "XOF"),
    CustomerCountryOption(name: "Malta", isoCode: "MT", callingCode: "+356", currencyCode: "EUR"),
    CustomerCountryOption(name: "Marshall Islands", isoCode: "MH", callingCode: "+692", currencyCode: "USD"),
    CustomerCountryOption(name: "Martinique", isoCode: "MQ", callingCode: "+596", currencyCode: "EUR"),
    CustomerCountryOption(name: "Mauritania", isoCode: "MR", callingCode: "+222", currencyCode: "MRU"),
    CustomerCountryOption(name: "Mauritius", isoCode: "MU", callingCode: "+230", currencyCode: "MUR"),
    CustomerCountryOption(name: "Mayotte", isoCode: "YT", callingCode: "+262", currencyCode: "EUR"),
    CustomerCountryOption(name: "Mexico", isoCode: "MX", callingCode: "+52", currencyCode: "MXN"),
    CustomerCountryOption(name: "Micronesia", isoCode: "FM", callingCode: "+691", currencyCode: "USD"),
    CustomerCountryOption(name: "Moldova", isoCode: "MD", callingCode: "+373", currencyCode: "MDL"),
    CustomerCountryOption(name: "Monaco", isoCode: "MC", callingCode: "+377", currencyCode: "EUR"),
    CustomerCountryOption(name: "Mongolia", isoCode: "MN", callingCode: "+976", currencyCode: "MNT"),
    CustomerCountryOption(name: "Montenegro", isoCode: "ME", callingCode: "", currencyCode: "EUR"),
    CustomerCountryOption(name: "Montserrat", isoCode: "MS", callingCode: "+1664", currencyCode: "XCD"),
    CustomerCountryOption(name: "Morocco", isoCode: "MA", callingCode: "+212", currencyCode: "MAD"),
    CustomerCountryOption(name: "Mozambique", isoCode: "MZ", callingCode: "+258", currencyCode: "MZN"),
    CustomerCountryOption(name: "Myanmar", isoCode: "MM", callingCode: "", currencyCode: "MMK"),
    CustomerCountryOption(name: "Namibia", isoCode: "NA", callingCode: "+264", currencyCode: "ZAR"),
    CustomerCountryOption(name: "Nauru", isoCode: "NR", callingCode: "+674", currencyCode: "AUD"),
    CustomerCountryOption(name: "Nepal", isoCode: "NP", callingCode: "+977", currencyCode: "NPR"),
    CustomerCountryOption(name: "Netherlands", isoCode: "NL", callingCode: "+31", currencyCode: "EUR"),
    CustomerCountryOption(name: "New Caledonia", isoCode: "NC", callingCode: "+687", currencyCode: "XPF"),
    CustomerCountryOption(name: "New Zealand", isoCode: "NZ", callingCode: "+64", currencyCode: "NZD"),
    CustomerCountryOption(name: "Nicaragua", isoCode: "NI", callingCode: "+505", currencyCode: "NIO"),
    CustomerCountryOption(name: "Niger", isoCode: "NE", callingCode: "+227", currencyCode: "XOF"),
    CustomerCountryOption(name: "Nigeria", isoCode: "NG", callingCode: "+234", currencyCode: "NGN"),
    CustomerCountryOption(name: "Niue", isoCode: "NU", callingCode: "+683", currencyCode: "NZD"),
    CustomerCountryOption(name: "Norfolk Island", isoCode: "NF", callingCode: "+672", currencyCode: "AUD"),
    CustomerCountryOption(name: "North Korea", isoCode: "KP", callingCode: "+850", currencyCode: "KPW"),
    CustomerCountryOption(name: "North Macedonia", isoCode: "MK", callingCode: "+389", currencyCode: "MKD"),
    CustomerCountryOption(name: "Northern Mariana Islands", isoCode: "MP", callingCode: "+1670", currencyCode: "USD"),
    CustomerCountryOption(name: "Norway", isoCode: "NO", callingCode: "+47", currencyCode: "NOK"),
    CustomerCountryOption(name: "Oman", isoCode: "OM", callingCode: "+968", currencyCode: "OMR"),
    CustomerCountryOption(name: "Pakistan", isoCode: "PK", callingCode: "+92", currencyCode: "PKR"),
    CustomerCountryOption(name: "Palau", isoCode: "PW", callingCode: "+680", currencyCode: "USD"),
    CustomerCountryOption(name: "Palestine", isoCode: "PS", callingCode: "", currencyCode: "ILS"),
    CustomerCountryOption(name: "Panama", isoCode: "PA", callingCode: "+507", currencyCode: "PAB"),
    CustomerCountryOption(name: "Papua New Guinea", isoCode: "PG", callingCode: "+675", currencyCode: "PGK"),
    CustomerCountryOption(name: "Paraguay", isoCode: "PY", callingCode: "+595", currencyCode: "PYG"),
    CustomerCountryOption(name: "Peru", isoCode: "PE", callingCode: "+51", currencyCode: "PEN"),
    CustomerCountryOption(name: "Philippines", isoCode: "PH", callingCode: "+63", currencyCode: "PHP"),
    CustomerCountryOption(name: "Pitcairn", isoCode: "PN", callingCode: "+64", currencyCode: "NZD"),
    CustomerCountryOption(name: "Poland", isoCode: "PL", callingCode: "+48", currencyCode: "PLN"),
    CustomerCountryOption(name: "Portugal", isoCode: "PT", callingCode: "+351", currencyCode: "EUR"),
    CustomerCountryOption(name: "Puerto Rico", isoCode: "PR", callingCode: "+1787", currencyCode: "USD"),
    CustomerCountryOption(name: "Qatar", isoCode: "QA", callingCode: "+974", currencyCode: "QAR"),
    CustomerCountryOption(name: "Romania", isoCode: "RO", callingCode: "+40", currencyCode: "RON"),
    CustomerCountryOption(name: "Russia", isoCode: "RU", callingCode: "+7", currencyCode: "RUB"),
    CustomerCountryOption(name: "Rwanda", isoCode: "RW", callingCode: "+250", currencyCode: "RWF"),
    CustomerCountryOption(name: "Réunion", isoCode: "RE", callingCode: "+262", currencyCode: "EUR"),
    CustomerCountryOption(name: "Saint Barthélemy", isoCode: "BL", callingCode: "", currencyCode: "EUR"),
    CustomerCountryOption(name: "Saint Helena, Ascension and Tristan da Cunha", isoCode: "SH", callingCode: "+290", currencyCode: "SHP"),
    CustomerCountryOption(name: "Saint Kitts and Nevis", isoCode: "KN", callingCode: "+1869", currencyCode: "XCD"),
    CustomerCountryOption(name: "Saint Lucia", isoCode: "LC", callingCode: "+1758", currencyCode: "XCD"),
    CustomerCountryOption(name: "Saint Martin (French part)", isoCode: "MF", callingCode: "", currencyCode: "EUR"),
    CustomerCountryOption(name: "Saint Pierre and Miquelon", isoCode: "PM", callingCode: "+508", currencyCode: "EUR"),
    CustomerCountryOption(name: "Saint Vincent and the Grenadines", isoCode: "VC", callingCode: "+1784", currencyCode: "XCD"),
    CustomerCountryOption(name: "Samoa", isoCode: "WS", callingCode: "+685", currencyCode: "WST"),
    CustomerCountryOption(name: "San Marino", isoCode: "SM", callingCode: "+378", currencyCode: "EUR"),
    CustomerCountryOption(name: "Sao Tome and Principe", isoCode: "ST", callingCode: "+239", currencyCode: "STN"),
    CustomerCountryOption(name: "Saudi Arabia", isoCode: "SA", callingCode: "+966", currencyCode: "SAR"),
    CustomerCountryOption(name: "Senegal", isoCode: "SN", callingCode: "+221", currencyCode: "XOF"),
    CustomerCountryOption(name: "Serbia", isoCode: "RS", callingCode: "+381", currencyCode: "RSD"),
    CustomerCountryOption(name: "Seychelles", isoCode: "SC", callingCode: "+248", currencyCode: "SCR"),
    CustomerCountryOption(name: "Sierra Leone", isoCode: "SL", callingCode: "+232", currencyCode: "SLE"),
    CustomerCountryOption(name: "Singapore", isoCode: "SG", callingCode: "+65", currencyCode: "SGD"),
    CustomerCountryOption(name: "Sint Maarten (Dutch part)", isoCode: "SX", callingCode: "", currencyCode: "XCG"),
    CustomerCountryOption(name: "Slovakia", isoCode: "SK", callingCode: "+421", currencyCode: "EUR"),
    CustomerCountryOption(name: "Slovenia", isoCode: "SI", callingCode: "+386", currencyCode: "EUR"),
    CustomerCountryOption(name: "Solomon Islands", isoCode: "SB", callingCode: "+677", currencyCode: "SBD"),
    CustomerCountryOption(name: "Somalia", isoCode: "SO", callingCode: "+252", currencyCode: "SOS"),
    CustomerCountryOption(name: "South Africa", isoCode: "ZA", callingCode: "+27", currencyCode: "ZAR"),
    CustomerCountryOption(name: "South Georgia and the South Sandwich Islands", isoCode: "GS", callingCode: "+500", currencyCode: "GBP"),
    CustomerCountryOption(name: "South Korea", isoCode: "KR", callingCode: "+82", currencyCode: "KRW"),
    CustomerCountryOption(name: "South Sudan", isoCode: "SS", callingCode: "+211", currencyCode: "SSP"),
    CustomerCountryOption(name: "Spain", isoCode: "ES", callingCode: "+34", currencyCode: "EUR"),
    CustomerCountryOption(name: "Sri Lanka", isoCode: "LK", callingCode: "+94", currencyCode: "LKR"),
    CustomerCountryOption(name: "Sudan", isoCode: "SD", callingCode: "+249", currencyCode: "SDG"),
    CustomerCountryOption(name: "Suriname", isoCode: "SR", callingCode: "+597", currencyCode: "SRD"),
    CustomerCountryOption(name: "Svalbard and Jan Mayen", isoCode: "SJ", callingCode: "+4779", currencyCode: "NOK"),
    CustomerCountryOption(name: "Sweden", isoCode: "SE", callingCode: "+46", currencyCode: "SEK"),
    CustomerCountryOption(name: "Switzerland", isoCode: "CH", callingCode: "+41", currencyCode: "CHF"),
    CustomerCountryOption(name: "Syria", isoCode: "SY", callingCode: "+963", currencyCode: "SYP"),
    CustomerCountryOption(name: "Taiwan", isoCode: "TW", callingCode: "+886", currencyCode: "TWD"),
    CustomerCountryOption(name: "Tajikistan", isoCode: "TJ", callingCode: "+992", currencyCode: "TJS"),
    CustomerCountryOption(name: "Tanzania", isoCode: "TZ", callingCode: "+255", currencyCode: "TZS"),
    CustomerCountryOption(name: "Thailand", isoCode: "TH", callingCode: "+66", currencyCode: "THB"),
    CustomerCountryOption(name: "Timor-Leste", isoCode: "TL", callingCode: "+670", currencyCode: "USD"),
    CustomerCountryOption(name: "Togo", isoCode: "TG", callingCode: "+228", currencyCode: "XOF"),
    CustomerCountryOption(name: "Tokelau", isoCode: "TK", callingCode: "+690", currencyCode: "NZD"),
    CustomerCountryOption(name: "Tonga", isoCode: "TO", callingCode: "+676", currencyCode: "TOP"),
    CustomerCountryOption(name: "Trinidad and Tobago", isoCode: "TT", callingCode: "+1868", currencyCode: "TTD"),
    CustomerCountryOption(name: "Tunisia", isoCode: "TN", callingCode: "+216", currencyCode: "TND"),
    CustomerCountryOption(name: "Turkmenistan", isoCode: "TM", callingCode: "+993", currencyCode: "TMT"),
    CustomerCountryOption(name: "Turks and Caicos Islands", isoCode: "TC", callingCode: "", currencyCode: "USD"),
    CustomerCountryOption(name: "Tuvalu", isoCode: "TV", callingCode: "+688", currencyCode: "AUD"),
    CustomerCountryOption(name: "Türkiye", isoCode: "TR", callingCode: "+90", currencyCode: "TRY"),
    CustomerCountryOption(name: "Uganda", isoCode: "UG", callingCode: "+256", currencyCode: "UGX"),
    CustomerCountryOption(name: "Ukraine", isoCode: "UA", callingCode: "+380", currencyCode: "UAH"),
    CustomerCountryOption(name: "United Arab Emirates", isoCode: "AE", callingCode: "+971", currencyCode: "AED"),
    CustomerCountryOption(name: "United Kingdom", isoCode: "GB", callingCode: "+44", currencyCode: "GBP"),
    CustomerCountryOption(name: "United States", isoCode: "US", callingCode: "+1", currencyCode: "USD"),
    CustomerCountryOption(name: "United States Minor Outlying Islands", isoCode: "UM", callingCode: "", currencyCode: "USD"),
    CustomerCountryOption(name: "Uruguay", isoCode: "UY", callingCode: "+598", currencyCode: "UYU"),
    CustomerCountryOption(name: "Uzbekistan", isoCode: "UZ", callingCode: "+998", currencyCode: "UZS"),
    CustomerCountryOption(name: "Vanuatu", isoCode: "VU", callingCode: "+678", currencyCode: "VUV"),
    CustomerCountryOption(name: "Vatican City", isoCode: "VA", callingCode: "", currencyCode: "EUR"),
    CustomerCountryOption(name: "Venezuela", isoCode: "VE", callingCode: "+58", currencyCode: "VES"),
    CustomerCountryOption(name: "Vietnam", isoCode: "VN", callingCode: "+84", currencyCode: "VND"),
    CustomerCountryOption(name: "Virgin Islands, British", isoCode: "VG", callingCode: "", currencyCode: "USD"),
    CustomerCountryOption(name: "Virgin Islands, U.S.", isoCode: "VI", callingCode: "", currencyCode: "USD"),
    CustomerCountryOption(name: "Wallis and Futuna", isoCode: "WF", callingCode: "+681", currencyCode: "XPF"),
    CustomerCountryOption(name: "Western Sahara", isoCode: "EH", callingCode: "+212", currencyCode: "MAD"),
    CustomerCountryOption(name: "Yemen", isoCode: "YE", callingCode: "+967", currencyCode: "YER"),
    CustomerCountryOption(name: "Zambia", isoCode: "ZM", callingCode: "+260", currencyCode: "ZMW"),
    CustomerCountryOption(name: "Zimbabwe", isoCode: "ZW", callingCode: "+263", currencyCode: "USD"),
    CustomerCountryOption(name: "Åland Islands", isoCode: "AX", callingCode: "", currencyCode: "EUR"),
  ];

  static const List<CustomerCurrencyOption> currencies = [
    CustomerCurrencyOption(code: "AED", name: "United Arab Emirates Dirham", symbol: "AED"),
    CustomerCurrencyOption(code: "AFN", name: "Afghan Afghani", symbol: "AFN"),
    CustomerCurrencyOption(code: "ALL", name: "Albanian Lek", symbol: "ALL"),
    CustomerCurrencyOption(code: "AMD", name: "Armenian Dram", symbol: "AMD"),
    CustomerCurrencyOption(code: "AOA", name: "Angolan Kwanza", symbol: "AOA"),
    CustomerCurrencyOption(code: "ARS", name: "Argentine Peso", symbol: "ARS"),
    CustomerCurrencyOption(code: "AUD", name: "Australian Dollar", symbol: "A\$"),
    CustomerCurrencyOption(code: "AWG", name: "Aruban Florin", symbol: "AWG"),
    CustomerCurrencyOption(code: "AZN", name: "Azerbaijani Manat", symbol: "AZN"),
    CustomerCurrencyOption(code: "BAM", name: "Bosnia-Herzegovina Convertible Mark", symbol: "BAM"),
    CustomerCurrencyOption(code: "BBD", name: "Barbadian Dollar", symbol: "BBD"),
    CustomerCurrencyOption(code: "BDT", name: "Bangladeshi Taka", symbol: "BDT"),
    CustomerCurrencyOption(code: "BGN", name: "Bulgarian Lev", symbol: "BGN"),
    CustomerCurrencyOption(code: "BHD", name: "Bahraini Dinar", symbol: "BHD"),
    CustomerCurrencyOption(code: "BIF", name: "Burundian Franc", symbol: "BIF"),
    CustomerCurrencyOption(code: "BMD", name: "Bermudan Dollar", symbol: "BMD"),
    CustomerCurrencyOption(code: "BND", name: "Brunei Dollar", symbol: "BND"),
    CustomerCurrencyOption(code: "BOB", name: "Bolivian Boliviano", symbol: "BOB"),
    CustomerCurrencyOption(code: "BRL", name: "Brazilian Real", symbol: "R\$"),
    CustomerCurrencyOption(code: "BSD", name: "Bahamian Dollar", symbol: "BSD"),
    CustomerCurrencyOption(code: "BWP", name: "Botswanan Pula", symbol: "BWP"),
    CustomerCurrencyOption(code: "BYN", name: "Belarusian Ruble", symbol: "BYN"),
    CustomerCurrencyOption(code: "BZD", name: "Belize Dollar", symbol: "BZD"),
    CustomerCurrencyOption(code: "CAD", name: "Canadian Dollar", symbol: "CA\$"),
    CustomerCurrencyOption(code: "CDF", name: "Congolese Franc", symbol: "CDF"),
    CustomerCurrencyOption(code: "CHF", name: "Swiss Franc", symbol: "CHF"),
    CustomerCurrencyOption(code: "CLP", name: "Chilean Peso", symbol: "CLP"),
    CustomerCurrencyOption(code: "CNY", name: "Chinese Yuan", symbol: "CN¥"),
    CustomerCurrencyOption(code: "COP", name: "Colombian Peso", symbol: "COP"),
    CustomerCurrencyOption(code: "CRC", name: "Costa Rican Colón", symbol: "CRC"),
    CustomerCurrencyOption(code: "CUP", name: "Cuban Peso", symbol: "CUP"),
    CustomerCurrencyOption(code: "CVE", name: "Cape Verdean Escudo", symbol: "CVE"),
    CustomerCurrencyOption(code: "CZK", name: "Czech Koruna", symbol: "CZK"),
    CustomerCurrencyOption(code: "DJF", name: "Djiboutian Franc", symbol: "DJF"),
    CustomerCurrencyOption(code: "DKK", name: "Danish Krone", symbol: "DKK"),
    CustomerCurrencyOption(code: "DOP", name: "Dominican Peso", symbol: "DOP"),
    CustomerCurrencyOption(code: "DZD", name: "Algerian Dinar", symbol: "DZD"),
    CustomerCurrencyOption(code: "EGP", name: "Egyptian Pound", symbol: "EGP"),
    CustomerCurrencyOption(code: "ERN", name: "Eritrean Nakfa", symbol: "ERN"),
    CustomerCurrencyOption(code: "ETB", name: "Ethiopian Birr", symbol: "ETB"),
    CustomerCurrencyOption(code: "EUR", name: "Euro", symbol: "€"),
    CustomerCurrencyOption(code: "FJD", name: "Fijian Dollar", symbol: "FJD"),
    CustomerCurrencyOption(code: "FKP", name: "Falkland Islands Pound", symbol: "FKP"),
    CustomerCurrencyOption(code: "GBP", name: "British Pound", symbol: "£"),
    CustomerCurrencyOption(code: "GEL", name: "Georgian Lari", symbol: "GEL"),
    CustomerCurrencyOption(code: "GHS", name: "Ghanaian Cedi", symbol: "GHS"),
    CustomerCurrencyOption(code: "GIP", name: "Gibraltar Pound", symbol: "GIP"),
    CustomerCurrencyOption(code: "GMD", name: "Gambian Dalasi", symbol: "GMD"),
    CustomerCurrencyOption(code: "GNF", name: "Guinean Franc", symbol: "GNF"),
    CustomerCurrencyOption(code: "GTQ", name: "Guatemalan Quetzal", symbol: "GTQ"),
    CustomerCurrencyOption(code: "GYD", name: "Guyanaese Dollar", symbol: "GYD"),
    CustomerCurrencyOption(code: "HKD", name: "Hong Kong Dollar", symbol: "HK\$"),
    CustomerCurrencyOption(code: "HNL", name: "Honduran Lempira", symbol: "HNL"),
    CustomerCurrencyOption(code: "HTG", name: "Haitian Gourde", symbol: "HTG"),
    CustomerCurrencyOption(code: "HUF", name: "Hungarian Forint", symbol: "HUF"),
    CustomerCurrencyOption(code: "IDR", name: "Indonesian Rupiah", symbol: "IDR"),
    CustomerCurrencyOption(code: "ILS", name: "Israeli New Shekel", symbol: "₪"),
    CustomerCurrencyOption(code: "INR", name: "Indian Rupee", symbol: "₹"),
    CustomerCurrencyOption(code: "IQD", name: "Iraqi Dinar", symbol: "IQD"),
    CustomerCurrencyOption(code: "IRR", name: "Iranian Rial", symbol: "IRR"),
    CustomerCurrencyOption(code: "ISK", name: "Icelandic Króna", symbol: "ISK"),
    CustomerCurrencyOption(code: "JMD", name: "Jamaican Dollar", symbol: "JMD"),
    CustomerCurrencyOption(code: "JOD", name: "Jordanian Dinar", symbol: "JOD"),
    CustomerCurrencyOption(code: "JPY", name: "Japanese Yen", symbol: "¥"),
    CustomerCurrencyOption(code: "KES", name: "Kenyan Shilling", symbol: "KES"),
    CustomerCurrencyOption(code: "KGS", name: "Kyrgystani Som", symbol: "KGS"),
    CustomerCurrencyOption(code: "KHR", name: "Cambodian Riel", symbol: "KHR"),
    CustomerCurrencyOption(code: "KMF", name: "Comorian Franc", symbol: "KMF"),
    CustomerCurrencyOption(code: "KPW", name: "North Korean Won", symbol: "KPW"),
    CustomerCurrencyOption(code: "KRW", name: "South Korean Won", symbol: "₩"),
    CustomerCurrencyOption(code: "KWD", name: "Kuwaiti Dinar", symbol: "KWD"),
    CustomerCurrencyOption(code: "KYD", name: "Cayman Islands Dollar", symbol: "KYD"),
    CustomerCurrencyOption(code: "KZT", name: "Kazakhstani Tenge", symbol: "KZT"),
    CustomerCurrencyOption(code: "LAK", name: "Laotian Kip", symbol: "LAK"),
    CustomerCurrencyOption(code: "LBP", name: "Lebanese Pound", symbol: "LBP"),
    CustomerCurrencyOption(code: "LKR", name: "Sri Lankan Rupee", symbol: "LKR"),
    CustomerCurrencyOption(code: "LRD", name: "Liberian Dollar", symbol: "LRD"),
    CustomerCurrencyOption(code: "LYD", name: "Libyan Dinar", symbol: "LYD"),
    CustomerCurrencyOption(code: "MAD", name: "Moroccan Dirham", symbol: "MAD"),
    CustomerCurrencyOption(code: "MDL", name: "Moldovan Leu", symbol: "MDL"),
    CustomerCurrencyOption(code: "MGA", name: "Malagasy Ariary", symbol: "MGA"),
    CustomerCurrencyOption(code: "MKD", name: "Macedonian Denar", symbol: "MKD"),
    CustomerCurrencyOption(code: "MMK", name: "Myanmar Kyat", symbol: "MMK"),
    CustomerCurrencyOption(code: "MNT", name: "Mongolian Tugrik", symbol: "MNT"),
    CustomerCurrencyOption(code: "MOP", name: "Macanese Pataca", symbol: "MOP"),
    CustomerCurrencyOption(code: "MRU", name: "Mauritanian Ouguiya", symbol: "MRU"),
    CustomerCurrencyOption(code: "MUR", name: "Mauritian Rupee", symbol: "MUR"),
    CustomerCurrencyOption(code: "MVR", name: "Maldivian Rufiyaa", symbol: "MVR"),
    CustomerCurrencyOption(code: "MWK", name: "Malawian Kwacha", symbol: "MWK"),
    CustomerCurrencyOption(code: "MXN", name: "Mexican Peso", symbol: "MX\$"),
    CustomerCurrencyOption(code: "MYR", name: "Malaysian Ringgit", symbol: "MYR"),
    CustomerCurrencyOption(code: "MZN", name: "Mozambican Metical", symbol: "MZN"),
    CustomerCurrencyOption(code: "NGN", name: "Nigerian Naira", symbol: "NGN"),
    CustomerCurrencyOption(code: "NIO", name: "Nicaraguan Córdoba", symbol: "NIO"),
    CustomerCurrencyOption(code: "NOK", name: "Norwegian Krone", symbol: "NOK"),
    CustomerCurrencyOption(code: "NPR", name: "Nepalese Rupee", symbol: "NPR"),
    CustomerCurrencyOption(code: "NZD", name: "New Zealand Dollar", symbol: "NZ\$"),
    CustomerCurrencyOption(code: "OMR", name: "Omani Rial", symbol: "OMR"),
    CustomerCurrencyOption(code: "PAB", name: "Panamanian Balboa", symbol: "PAB"),
    CustomerCurrencyOption(code: "PEN", name: "Peruvian Sol", symbol: "PEN"),
    CustomerCurrencyOption(code: "PGK", name: "Papua New Guinean Kina", symbol: "PGK"),
    CustomerCurrencyOption(code: "PHP", name: "Philippine Peso", symbol: "₱"),
    CustomerCurrencyOption(code: "PKR", name: "Pakistani Rupee", symbol: "PKR"),
    CustomerCurrencyOption(code: "PLN", name: "Polish Zloty", symbol: "PLN"),
    CustomerCurrencyOption(code: "PYG", name: "Paraguayan Guarani", symbol: "PYG"),
    CustomerCurrencyOption(code: "QAR", name: "Qatari Riyal", symbol: "QAR"),
    CustomerCurrencyOption(code: "RON", name: "Romanian Leu", symbol: "RON"),
    CustomerCurrencyOption(code: "RSD", name: "Serbian Dinar", symbol: "RSD"),
    CustomerCurrencyOption(code: "RUB", name: "Russian Ruble", symbol: "RUB"),
    CustomerCurrencyOption(code: "RWF", name: "Rwandan Franc", symbol: "RWF"),
    CustomerCurrencyOption(code: "SAR", name: "Saudi Riyal", symbol: "SAR"),
    CustomerCurrencyOption(code: "SBD", name: "Solomon Islands Dollar", symbol: "SBD"),
    CustomerCurrencyOption(code: "SCR", name: "Seychellois Rupee", symbol: "SCR"),
    CustomerCurrencyOption(code: "SDG", name: "Sudanese Pound", symbol: "SDG"),
    CustomerCurrencyOption(code: "SEK", name: "Swedish Krona", symbol: "SEK"),
    CustomerCurrencyOption(code: "SGD", name: "Singapore Dollar", symbol: "SGD"),
    CustomerCurrencyOption(code: "SHP", name: "St. Helena Pound", symbol: "SHP"),
    CustomerCurrencyOption(code: "SLE", name: "Sierra Leonean Leone", symbol: "SLE"),
    CustomerCurrencyOption(code: "SOS", name: "Somali Shilling", symbol: "SOS"),
    CustomerCurrencyOption(code: "SRD", name: "Surinamese Dollar", symbol: "SRD"),
    CustomerCurrencyOption(code: "SSP", name: "South Sudanese Pound", symbol: "SSP"),
    CustomerCurrencyOption(code: "STN", name: "São Tomé & Príncipe Dobra", symbol: "STN"),
    CustomerCurrencyOption(code: "SYP", name: "Syrian Pound", symbol: "SYP"),
    CustomerCurrencyOption(code: "SZL", name: "Swazi Lilangeni", symbol: "SZL"),
    CustomerCurrencyOption(code: "THB", name: "Thai Baht", symbol: "THB"),
    CustomerCurrencyOption(code: "TJS", name: "Tajikistani Somoni", symbol: "TJS"),
    CustomerCurrencyOption(code: "TMT", name: "Turkmenistani Manat", symbol: "TMT"),
    CustomerCurrencyOption(code: "TND", name: "Tunisian Dinar", symbol: "TND"),
    CustomerCurrencyOption(code: "TOP", name: "Tongan Paʻanga", symbol: "TOP"),
    CustomerCurrencyOption(code: "TRY", name: "Turkish Lira", symbol: "TRY"),
    CustomerCurrencyOption(code: "TTD", name: "Trinidad & Tobago Dollar", symbol: "TTD"),
    CustomerCurrencyOption(code: "TWD", name: "New Taiwan Dollar", symbol: "NT\$"),
    CustomerCurrencyOption(code: "TZS", name: "Tanzanian Shilling", symbol: "TZS"),
    CustomerCurrencyOption(code: "UAH", name: "Ukrainian Hryvnia", symbol: "UAH"),
    CustomerCurrencyOption(code: "UGX", name: "Ugandan Shilling", symbol: "UGX"),
    CustomerCurrencyOption(code: "USD", name: "US Dollar", symbol: "\$"),
    CustomerCurrencyOption(code: "UYU", name: "Uruguayan Peso", symbol: "UYU"),
    CustomerCurrencyOption(code: "UZS", name: "Uzbekistani Som", symbol: "UZS"),
    CustomerCurrencyOption(code: "VES", name: "Venezuelan Bolívar", symbol: "VES"),
    CustomerCurrencyOption(code: "VND", name: "Vietnamese Dong", symbol: "₫"),
    CustomerCurrencyOption(code: "VUV", name: "Vanuatu Vatu", symbol: "VUV"),
    CustomerCurrencyOption(code: "WST", name: "Samoan Tala", symbol: "WST"),
    CustomerCurrencyOption(code: "XAF", name: "Central African CFA Franc", symbol: "FCFA"),
    CustomerCurrencyOption(code: "XCD", name: "East Caribbean Dollar", symbol: "EC\$"),
    CustomerCurrencyOption(code: "XCG", name: "Caribbean guilder", symbol: "Cg."),
    CustomerCurrencyOption(code: "XOF", name: "West African CFA Franc", symbol: "F CFA"),
    CustomerCurrencyOption(code: "XPF", name: "CFP Franc", symbol: "CFPF"),
    CustomerCurrencyOption(code: "XXX", name: "No universal currency", symbol: "¤"),
    CustomerCurrencyOption(code: "YER", name: "Yemeni Rial", symbol: "YER"),
    CustomerCurrencyOption(code: "ZAR", name: "South African Rand", symbol: "ZAR"),
    CustomerCurrencyOption(code: "ZMW", name: "Zambian Kwacha", symbol: "ZMW"),
  ];

  static const Map<String, String> _countryAliases = {
    'usa': 'US',
    'unitedstatesofamerica': 'US',
    'america': 'US',
    'uk': 'GB',
    'greatbritain': 'GB',
    'england': 'GB',
    'uae': 'AE',
    'ksa': 'SA',
    'southkorea': 'KR',
    'republicofkorea': 'KR',
    'northkorea': 'KP',
    'russianfederation': 'RU',
    'vietnam': 'VN',
    'vietname': 'VN',
    'czechrepublic': 'CZ',
    'ivorycoast': 'CI',
    'boliviaplurinationalstateof': 'BO',
    'tanzaniaunitedrepublicof': 'TZ',
    'moldovarepublicof': 'MD',
  };

  static String _normalizeCountryName(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static CustomerCountryOption byCode(String? code, {String fallbackCode = 'IN'}) {
    final normalized = (code ?? '').trim().toUpperCase();
    for (final country in countries) {
      if (country.isoCode == normalized) return country;
    }

    final fallback = fallbackCode.trim().toUpperCase();
    for (final country in countries) {
      if (country.isoCode == fallback) return country;
    }
    return countries.first;
  }

  static CustomerCountryOption resolve({String? code, String? name, String fallbackCode = 'IN'}) {
    final normalizedCode = (code ?? '').trim().toUpperCase();
    if (normalizedCode.isNotEmpty) {
      for (final country in countries) {
        if (country.isoCode == normalizedCode) return country;
      }
    }

    final normalizedName = _normalizeCountryName((name ?? '').trim());
    if (normalizedName.isNotEmpty) {
      final aliasCode = _countryAliases[normalizedName];
      if (aliasCode != null) return byCode(aliasCode, fallbackCode: fallbackCode);

      for (final country in countries) {
        if (_normalizeCountryName(country.name) == normalizedName) return country;
      }
    }

    return byCode(fallbackCode);
  }

  static CustomerCurrencyOption currencyByCode(String? code, {String fallbackCode = 'INR'}) {
    final normalized = (code ?? '').trim().toUpperCase();
    for (final currency in currencies) { if (currency.code == normalized) return currency; }
    for (final currency in currencies) { if (currency.code == fallbackCode) return currency; }
    return currencies.first;
  }
}
