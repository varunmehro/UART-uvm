class uart_base_test extends uvm_test;
    `uvm_component_utils(uart_base_test)

    uart_env m_env;
    uart_config m_cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env = uart_env::type_id::create("m_env", this);
        m_cfg = uart_config::type_id::create("m_cfg");
        // Configure defaults
        m_cfg.is_active = UVM_ACTIVE;
        m_cfg.parity_cfg = 1; // Enable parity (Odd) for error testing
        uvm_config_db#(uart_config)::set(this, "*", "m_cfg", m_cfg);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        // Reset sequence or delay
        #1000ns; 
        phase.drop_objection(this);
    endtask

endclass

class uart_tx_test extends uart_base_test;
    `uvm_component_utils(uart_tx_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uart_tx_seq seq;
        phase.raise_objection(this);
        seq = uart_tx_seq::type_id::create("seq");
        if(!seq.randomize()) `uvm_error("TEST", "Randomization failed")
        seq.start(m_env.m_agent.m_sequencer);
        phase.drop_objection(this);
    endtask
endclass

class uart_rand_test extends uart_base_test;
    `uvm_component_utils(uart_rand_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uart_tx_seq seq;
        phase.raise_objection(this);
        seq = uart_tx_seq::type_id::create("seq");
        // Randomize sequence params
        if(!seq.randomize() with { num_trans inside {[50:100]}; }) `uvm_error("TEST", "Randomization failed")
        seq.start(m_env.m_agent.m_sequencer);
        phase.drop_objection(this);
    endtask
endclass


class uart_error_test extends uart_base_test;
    `uvm_component_utils(uart_error_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uart_err_seq seq;
        phase.raise_objection(this);
        // Wait for Reset
        wait(m_env.m_cfg.is_active == UVM_ACTIVE);
        #200ns;
        
        seq = uart_err_seq::type_id::create("seq");
        seq.start(m_env.m_agent.m_sequencer);
        #200us; // Drain time
        phase.drop_objection(this);
    endtask
endclass

class uart_b2b_seq extends uart_base_seq;
    `uvm_object_utils(uart_b2b_seq)
    
    function new(string name="uart_b2b_seq");
        super.new(name);
    endfunction
    
    task body();
        repeat(20) begin
             req = uart_trans::type_id::create("req");
             start_item(req);
             if(!req.randomize() with { delay == 0; baud_div == 651; parity_type == 0; }) 
                `uvm_error("SEQ", "Randomization failed")
             finish_item(req);
        end
    endtask
endclass

class uart_b2b_test extends uart_base_test;
    `uvm_component_utils(uart_b2b_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        uart_b2b_seq seq;
        phase.raise_objection(this);
        // Wait for Reset
        wait(m_env.m_cfg.is_active == UVM_ACTIVE);
        #200ns; // Wait for reset (100ns) + margin

        seq = uart_b2b_seq::type_id::create("seq");
        seq.start(m_env.m_agent.m_sequencer);
        phase.drop_objection(this);
    endtask
endclass
