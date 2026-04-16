// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Cognitio S.r.l.

package core

// #NetworkPort is an abstract listen/publish port (Domain 1 — no host binding).
#NetworkPort: {
	port:     int & >=1 & <=65535
	protocol: *"TCP" | "UDP" | "SCTP"
	name?:    string
}

// #PortList is a non-empty ordered list used by gateways and servers.
#PortList: [...#NetworkPort]
