class uart_env extends uvm_env;
    `uvm_component_utils(uart_env)

    uart_agent      m_agent;
    uart_scoreboard m_scoreboard;
    uart_coverage   m_cov;
    uart_config     m_cfg;


    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(uart_config)::get(this, "", "m_cfg", m_cfg)) begin
             m_cfg = uart_config::type_id::create("m_cfg");
        end
        
        // Pass config to agent
        uvm_config_db#(uart_config)::set(this, "m_agent", "m_cfg", m_cfg);
        
        m_agent = uart_agent::type_id::create("m_agent", this);
        m_scoreboard = uart_scoreboard::type_id::create("m_scoreboard", this);
        m_cov = uart_coverage::type_id::create("m_cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        m_agent.m_monitor.ap.connect(m_scoreboard.item_collected_export);
        m_agent.m_monitor.ap.connect(m_cov.analysis_export);
    endfunction


endclass
