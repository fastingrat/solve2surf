'use strict';
'require view';
'require form';
'require rpc';

// RPC call to get the list of active network interfaces
var callInitStatus = rpc.declare({
    object: 'network.interface',
    method: 'dump',
    expect: { interface: [] }
});

return view.extend({
    load: function() {
        return callInitStatus();
    },

    render: function(ifaces) {
        var m, s, o;

        // "solve2surf" corresponds to our UCI file name (/etc/config/solve2surf)
        m = new form.Map('solve2surf', _('Solve2Surf Configuration'),
            _('Require users to solve challenges fetched from an external object store before accessing the internet.'));

        // "main" corresponds to the `config global 'main'` section in our UCI file
        s = m.section(form.NamedSection, 'main', 'global', _('General Settings'));
        s.addremove = false; // Prevent the user from deleting the main config block

        // Enable Toggle
        o = s.option(form.Flag, 'enabled', _('Enable Solve2Surf'),
            _('Turn the captive portal on or off.'));
        o.rmempty = false;

        // Interface Selection Dropdown
        o = s.option(form.ListValue, 'interface', _('Network Interface'),
            _('The interface that guests will connect to (e.g., Guest WiFi network).'));

        // Populate the dropdown with active interfaces returned by ubus
        for (var i = 0; i < ifaces.length; i++) {
            // We ignore loopback and aliases for safety
            if (ifaces[i].interface != 'loopback' && !ifaces[i].interface.match(/^@/)) {
                o.value(ifaces[i].interface, ifaces[i].interface);
            }
        }
        o.rmempty = false;

        // Object Storage URL
        o = s.option(form.Value, 'storage_url', _('Object Storage URL'),
            _('The URL to your problems.json file (e.g., Cloudflare R2, AWS S3).'));
        o.placeholder = 'https://.../problems.json';
        o.datatype = 'url';
        o.rmempty = false;

        // Access Duration
        o = s.option(form.Value, 'duration', _('Access Duration (Minutes)'),
            _('How long a user gets internet access after solving a problem.'));
        o.datatype = 'uinteger';
        o.placeholder = '60';
        o.rmempty = false;

        // External Grading API
        o = s.option(form.Value, 'grading_api', _('Grading API URL'),
            _('Optional: The URL for evaluating complex AI/Public tasks.'));
        o.placeholder = 'https://api.../grade';
        o.datatype = 'url';
        o.rmempty = true; // This one can be empty if they only use local logic

        // Security Key (Hidden by default, shown as a password field)
        o = s.option(form.Value, 'fas_key', _('FAS Security Key'),
            _('Shared secret between OpenNDS and the Solve2Surf validation script.'));
        o.password = true;
        o.rmempty = false;

        return m.render();
    }
});
