  class qos_smoke_test extends qos_base_test;
    `uvm_component_utils(qos_smoke_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      qos_csr_program_seq csr_seq;
      qos_basic_source_seq src_seq[NUM_REQ];

      phase.raise_objection(this);

      csr_seq = qos_csr_program_seq::type_id::create("csr_seq");
      csr_seq.start(env.csr_agent.seqr);

      fork
        for (int i = 0; i < NUM_REQ; i++) begin
          automatic int j = i;
          begin
            src_seq[j] = qos_basic_source_seq::type_id::create($sformatf("src_seq_%0d", j));
            src_seq[j].src = j;
            src_seq[j].start(env.src_agent[j].seqr);
          end
        end
      join

      wait_scoreboard_drain();
      phase.drop_objection(this);
    endtask
  endclass
