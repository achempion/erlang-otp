{application, asn1,
 [{description, "The Erlang ASN1 compiler version 1.3.3.1"},
  {vsn, "1.3.3.1"},
  {modules, [
	asn1rt,
	asn1rt_ber,
	asn1rt_per,
	asn1rt_ber_v1,
	asn1rt_per_v1,
	asn1rt_ber_bin,
	asn1rt_per_bin,
	asn1rt_check
             ]},
  {registered, [
		]},
  {env, []},
  {applications, [kernel, stdlib]}
  ]}.