class uart_agent extends uvm_agent;
    `uvm_component_utils(uart_agent)

    uart_driver    m_driver;
    uart_sequencer m_sequencer;
    uart_monitor   m_monitor;
    uart_config    m_cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(uart_config)::get(this, "", "m_cfg", m_cfg)) begin
            `uvm_info("NO_CFG", "Creating default config", UVM_LOW)
            m_cfg = uart_config::type_id::create("m_cfg");
        end
        
        uvm_config_db#(uart_config)::set(this, "m_monitor", "m_cfg", m_cfg);
        m_monitor = uart_monitor::type_id::create("m_monitor", this);
        
        if (m_cfg.is_active == UVM_ACTIVE) begin
            m_driver = uart_driver::type_id::create("m_driver", this);
            m_sequencer = uart_sequencer::type_id::create("m_sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        if (m_cfg.is_active == UVM_ACTIVE) begin
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
        end
    endfunction

endclass
