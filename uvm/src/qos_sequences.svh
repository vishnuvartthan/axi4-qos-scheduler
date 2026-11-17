  class qos_csr_program_seq extends uvm_sequence #(qos_csr_item);
    `uvm_object_utils(qos_csr_program_seq)
    int unsigned weights[NUM_REQ] = '{1,2,4,8};
    int unsigned aging = 8'h40;
    function new(string name = "qos_csr_program_seq"); super.new(name); endfunction
    task body();
      qos_csr_item tr;
      for (int i = 0; i < NUM_REQ; i++) begin
        tr = qos_csr_item::type_id::create("csr_weight_wr");
        tr.write = 1'b1; tr.addr = 8'(i*4); tr.data = weights[i]; tr.strb = 4'hf;
        start_item(tr); finish_item(tr);
      end
      tr = qos_csr_item::type_id::create("csr_age_wr");
      tr.write = 1'b1; tr.addr = 8'h10; tr.data = aging; tr.strb = 4'hf;
      start_item(tr); finish_item(tr);
    endtask
  endclass

  class qos_basic_source_seq extends uvm_sequence #(qos_axi_item);
    `uvm_object_utils(qos_basic_source_seq)
    int unsigned src = 0;
    function new(string name = "qos_basic_source_seq"); super.new(name); endfunction

    task body();
      qos_axi_item tr;
      tr = qos_axi_item::type_id::create("ar");
      start_item(tr);
      if (!tr.randomize() with {
            kind == QOS_AR;
            side == QOS_SIDE_SRC;
            src == local::src;
            len == 0;
            id == local::src;
            addr[15:12] == local::src;
          })
        `uvm_fatal("BASIC_SRC_RAND",
          $sformatf("AR randomization failed for source %0d", src))
      finish_item(tr);

      tr = qos_axi_item::type_id::create("aw");
      start_item(tr);
      if (!tr.randomize() with {
            kind == QOS_AW;
            side == QOS_SIDE_SRC;
            src == local::src;
            len == 1;
            id == local::src;
            addr[15:12] == local::src;
          })
        `uvm_fatal("BASIC_SRC_RAND",
          $sformatf("AW randomization failed for source %0d", src))
      finish_item(tr);

      for (int beat = 0; beat < 2; beat++) begin
        tr = qos_axi_item::type_id::create("w");
        start_item(tr);
        if (!tr.randomize() with {
              kind == QOS_W;
              side == QOS_SIDE_SRC;
              src == local::src;
              strb == 4'hf;
              last == (beat == 1);
              data[7:0] == beat[7:0];
            })
          `uvm_fatal("BASIC_SRC_RAND",
            $sformatf("W randomization failed for source %0d beat %0d", src, beat))
        finish_item(tr);
      end
    endtask
  endclass

  class qos_csr_access_seq extends uvm_sequence #(qos_csr_item);
    `uvm_object_utils(qos_csr_access_seq)

    bit        write;
    bit [7:0]  addr;
    bit [31:0] data;
    bit [3:0]  strb = 4'hf;
    bit [31:0] rdata;

    function new(string name = "qos_csr_access_seq");
      super.new(name);
    endfunction

    task body();
      qos_csr_item tr;
      tr = qos_csr_item::type_id::create("csr_access");

      start_item(tr);
      tr.write = write;
      tr.addr  = addr;
      tr.data  = data;
      tr.strb  = strb;
      finish_item(tr);

      rdata = tr.rdata;
    endtask
  endclass


  class qos_ar_stream_seq extends uvm_sequence #(qos_axi_item);
    `uvm_object_utils(qos_ar_stream_seq)

    int unsigned src = 0;
    int unsigned n_txn = 32;
    int unsigned idle_max = 0;
    int unsigned max_len = 0;
    bit same_id = 0;
    int unsigned fixed_id = 0;
    bit fixed_len_en = 0;
    int unsigned fixed_len = 0;

    function new(string name = "qos_ar_stream_seq");
      super.new(name);
    endfunction

    task body();
      qos_axi_item tr;
      int unsigned txn_len;

      for (int k = 0; k < n_txn; k++) begin
        txn_len = fixed_len_en ? fixed_len : $urandom_range(0, max_len);

        tr = qos_axi_item::type_id::create($sformatf("ar_%0d", k));
        start_item(tr);

        tr.kind        = QOS_AR;
        tr.side        = QOS_SIDE_SRC;
        tr.src         = src;
        tr.qos         = src[AXI_QOS_W-1:0];
        tr.id          = same_id ? fixed_id : ((src << 2) ^ k);
        tr.addr        = 32'h1000_0000 + (src << 20) + (k << 4);
        tr.len         = txn_len[AXI_LEN_W-1:0];
        tr.data        = '0;
        tr.strb        = '0;
        tr.last        = 1'b0;
        tr.resp        = 2'b00;
        tr.idle_cycles = (idle_max == 0) ? 0 : $urandom_range(0, idle_max);

        finish_item(tr);
      end
    endtask
  endclass

  class qos_aw_only_seq extends uvm_sequence #(qos_axi_item);
    `uvm_object_utils(qos_aw_only_seq)

    int unsigned src = 0;
    int unsigned n_txn = 1;
    int unsigned idle_max = 0;
    bit same_id = 0;
    int unsigned fixed_id = 0;
    int unsigned fixed_len = 0;

    function new(string name = "qos_aw_only_seq");
      super.new(name);
    endfunction

    task body();
      qos_axi_item tr;

      for (int k = 0; k < n_txn; k++) begin
        tr = qos_axi_item::type_id::create($sformatf("aw_%0d", k));
        start_item(tr);
        tr.kind        = QOS_AW;
        tr.side        = QOS_SIDE_SRC;
        tr.src         = src;
        tr.qos         = src[AXI_QOS_W-1:0];
        tr.id          = same_id ? fixed_id : ((src << 2) ^ k);
        tr.addr        = 32'h3000_0000 + (src << 20) + (k << 6);
        tr.len         = fixed_len[AXI_LEN_W-1:0];
        tr.data        = '0;
        tr.strb        = '0;
        tr.last        = 1'b0;
        tr.resp        = 2'b00;
        tr.idle_cycles = (idle_max == 0) ? 0 : $urandom_range(0, idle_max);
        finish_item(tr);
      end
    endtask
  endclass

  class qos_w_only_seq extends uvm_sequence #(qos_axi_item);
    `uvm_object_utils(qos_w_only_seq)

    int unsigned src = 0;
    int unsigned n_txn = 1;
    int unsigned idle_max = 0;
    int unsigned fixed_len = 0;

    function new(string name = "qos_w_only_seq");
      super.new(name);
    endfunction

    task body();
      qos_axi_item tr;

      for (int k = 0; k < n_txn; k++) begin
        for (int beat = 0; beat <= fixed_len; beat++) begin
          tr = qos_axi_item::type_id::create($sformatf("w_%0d_%0d", k, beat));
          start_item(tr);
          tr.kind        = QOS_W;
          tr.side        = QOS_SIDE_SRC;
          tr.src         = src;
          tr.id          = '0;
          tr.addr        = '0;
          tr.len         = '0;
          tr.data        = 32'hB000_0000 | (src << 24) | (k << 8) | beat;
          tr.strb        = 4'hf;
          tr.last        = (beat == fixed_len);
          tr.resp        = 2'b00;
          tr.idle_cycles = (idle_max == 0) ? 0 : $urandom_range(0, idle_max);
          finish_item(tr);
        end
      end
    endtask
  endclass


  class qos_aw_w_stream_seq extends uvm_sequence #(qos_axi_item);
    `uvm_object_utils(qos_aw_w_stream_seq)

    int unsigned src = 0;
    int unsigned n_txn = 16;
    int unsigned idle_max = 0;
    int unsigned max_len = 3;
    bit same_id = 0;
    int unsigned fixed_id = 0;
    bit fixed_len_en = 0;
    int unsigned fixed_len = 0;

    function new(string name = "qos_aw_w_stream_seq");
      super.new(name);
    endfunction

    task body();
      qos_axi_item tr;
      int unsigned txn_len;

      for (int k = 0; k < n_txn; k++) begin
        txn_len = fixed_len_en ? fixed_len : $urandom_range(0, max_len);

        tr = qos_axi_item::type_id::create($sformatf("aw_%0d", k));
        start_item(tr);
        tr.kind        = QOS_AW;
        tr.side        = QOS_SIDE_SRC;
        tr.src         = src;
        tr.qos         = src[AXI_QOS_W-1:0];
        tr.id          = same_id ? fixed_id : ((src << 2) ^ k);
        tr.addr        = 32'h2000_0000 + (src << 20) + (k << 6);
        tr.len         = txn_len[AXI_LEN_W-1:0];
        tr.data        = '0;
        tr.strb        = '0;
        tr.last        = 1'b0;
        tr.resp        = 2'b00;
        tr.idle_cycles = (idle_max == 0) ? 0 : $urandom_range(0, idle_max);
        finish_item(tr);

        for (int beat = 0; beat <= txn_len; beat++) begin
          tr = qos_axi_item::type_id::create($sformatf("w_%0d_%0d", k, beat));
          start_item(tr);
          tr.kind        = QOS_W;
          tr.side        = QOS_SIDE_SRC;
          tr.src         = src;
          tr.id          = '0;
          tr.addr        = '0;
          tr.len         = '0;
          tr.data        = 32'hA000_0000 | (src << 24) | (k << 8) | beat;
          tr.strb        = 4'hf;
          tr.last        = (beat == txn_len);
          tr.resp        = 2'b00;
          tr.idle_cycles = (idle_max == 0) ? 0 : $urandom_range(0, idle_max);
          finish_item(tr);
        end
      end
    endtask
  endclass

  class qos_cr_ar_stream_seq extends uvm_sequence #(qos_axi_item);
    `uvm_object_utils(qos_cr_ar_stream_seq)

    int unsigned src = 0;
    int unsigned n_txn = 32;
    int unsigned idle_max = 8;
    int unsigned max_len = 15;
    bit same_id = 0;
    int unsigned fixed_id = 0;
    bit randomize_sideband = 0;
    int unsigned generated_beats;

    function new(string name = "qos_cr_ar_stream_seq");
      super.new(name);
    endfunction

    task body();
      qos_axi_item tr;

      if (src >= NUM_REQ)
        `uvm_fatal("CR_AR_CFG", $sformatf("source %0d is outside [0:%0d]", src, NUM_REQ-1))

      if (max_len > 15)
        `uvm_fatal("CR_AR_CFG", $sformatf("max_len=%0d exceeds constrained project limit 15", max_len))

      if (idle_max > 8)
        `uvm_fatal("CR_AR_CFG", $sformatf("idle_max=%0d exceeds constrained project limit 8", idle_max))

      if (same_id && (fixed_id >= (1 << AXI_ID_W)))
        `uvm_fatal("CR_AR_CFG", $sformatf("fixed_id=0x%0h exceeds the %0d bit AXI ID range",
                                          fixed_id, AXI_ID_W))

      generated_beats = 0;

      for (int k = 0; k < n_txn; k++) begin
        tr = qos_axi_item::type_id::create($sformatf("cr_ar_%0d", k));
        tr.default_sideband = !randomize_sideband;
        start_item(tr);

        if (!tr.randomize() with {
              kind == QOS_AR;
              side == QOS_SIDE_SRC;
              src == local::src;
              len <= local::max_len;
              if (local::same_id)
                id == local::fixed_id;
              addr[31:28] == 4'h1;
              addr[23:20] == local::src;
              addr[1:0] == 0;
              (addr[11:0] + (len * 4)) <= 12'hffc;
              data == 0;
              strb == 0;
              last == 0;
              resp == 0;
              idle_cycles <= local::idle_max;

              if (local::randomize_sideband) {
                size == (k % 3);
                burst == ((k / 3) % 3);
                lock == ((k / 9) % 2);
                cache == ((k + (local::src * 3)) % 16);
                prot == ((k + local::src) % 8);
                qos == ((k + (local::src * 5)) % 16);

                if (burst == 2)
                  len inside {1, 3, 7, 15};
              }
            })
          `uvm_fatal("CR_AR_RAND", $sformatf("AR randomization failed for source %0d transaction %0d", src, k))

        finish_item(tr);
        generated_beats += tr.len + 1;
      end
    endtask
  endclass

  class qos_cr_aw_w_stream_seq extends uvm_sequence #(qos_axi_item);
    `uvm_object_utils(qos_cr_aw_w_stream_seq)

    int unsigned src = 0;
    int unsigned n_txn = 16;
    int unsigned idle_max = 8;
    int unsigned max_len = 15;
    bit same_id = 0;
    int unsigned fixed_id = 0;
    bit randomize_sideband = 0;
    int unsigned generated_beats;

    function new(string name = "qos_cr_aw_w_stream_seq");
      super.new(name);
    endfunction

    task body();
      qos_axi_item tr;
      int unsigned txn_len;

      if (src >= NUM_REQ)
        `uvm_fatal("CR_AW_W_CFG", $sformatf("source %0d is outside [0:%0d]", src, NUM_REQ-1))

      if (max_len > 15)
        `uvm_fatal("CR_AW_W_CFG", $sformatf("max_len=%0d exceeds constrained project limit 15", max_len))

      if (idle_max > 8)
        `uvm_fatal("CR_AW_W_CFG", $sformatf("idle_max=%0d exceeds constrained project limit 8", idle_max))

      if (same_id && (fixed_id >= (1 << AXI_ID_W)))
        `uvm_fatal("CR_AW_W_CFG", $sformatf("fixed_id=0x%0h exceeds the %0d bit AXI ID range",
                                            fixed_id, AXI_ID_W))

      generated_beats = 0;

      for (int k = 0; k < n_txn; k++) begin
        tr = qos_axi_item::type_id::create($sformatf("cr_aw_%0d", k));
        tr.default_sideband = !randomize_sideband;
        start_item(tr);

        if (!tr.randomize() with {
              kind == QOS_AW;
              side == QOS_SIDE_SRC;
              src == local::src;
              len <= local::max_len;
              if (local::same_id)
                id == local::fixed_id;
              addr[31:28] == 4'h2;
              addr[23:20] == local::src;
              addr[1:0] == 0;
              (addr[11:0] + (len * 4)) <= 12'hffc;
              data == 0;
              strb == 0;
              last == 0;
              resp == 0;
              idle_cycles <= local::idle_max;

              if (local::randomize_sideband) {
                size == (k % 3);
                burst == ((k / 3) % 3);
                lock == ((k / 9) % 2);
                cache == ((k + (local::src * 3)) % 16);
                prot == ((k + local::src) % 8);
                qos == ((k + (local::src * 5)) % 16);

                if (burst == 2)
                  len inside {1, 3, 7, 15};
              }
            })
          `uvm_fatal("CR_AW_RAND", $sformatf("AW randomization failed for source %0d transaction %0d", src, k))

        finish_item(tr);
        txn_len = tr.len;

        for (int beat = 0; beat <= txn_len; beat++) begin
          tr = qos_axi_item::type_id::create($sformatf("cr_w_%0d_%0d", k, beat));
          start_item(tr);

          if (!tr.randomize() with {
                kind == QOS_W;
                side == QOS_SIDE_SRC;
                src == local::src;
                id == 0;
                mid == 0;
                addr == 0;
                len == 0;
                last == (beat == txn_len);
                resp == 0;
                idle_cycles <= local::idle_max;
              })
            `uvm_fatal("CR_W_RAND",
              $sformatf("W randomization failed for source %0d transaction %0d beat %0d",
                        src, k, beat))

          finish_item(tr);
          generated_beats++;
        end
      end
    endtask
  endclass
