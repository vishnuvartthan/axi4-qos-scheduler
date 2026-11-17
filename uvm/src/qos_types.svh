  localparam int unsigned NUM_REQ    = 4;
  localparam int unsigned AXI_ID_W   = 4;
  localparam int unsigned AXI_ADDR_W = 32;
  localparam int unsigned AXI_DATA_W = 32;
  localparam int unsigned AXI_LEN_W  = 8;
  localparam int unsigned AXI_SIZE_W = 3;
  localparam int unsigned AXI_BURST_W = 2;
  localparam int unsigned AXI_LOCK_W = 1;
  localparam int unsigned AXI_CACHE_W = 4;
  localparam int unsigned AXI_PROT_W = 3;
  localparam int unsigned AXI_QOS_W = 4;
  localparam int unsigned AXI_STRB_W = AXI_DATA_W / 8;
  localparam int unsigned REQ_IDX_W  = 2;
  localparam int unsigned M_AXI_ID_W = AXI_ID_W + REQ_IDX_W;

  typedef enum int {QOS_AR, QOS_AW, QOS_W, QOS_R, QOS_B, QOS_CSR_WR, QOS_CSR_RD} qos_kind_e;
  typedef enum int {QOS_SIDE_SRC, QOS_SIDE_MST, QOS_SIDE_CSR} qos_side_e;

  class qos_axi_item extends uvm_sequence_item;
    rand qos_kind_e kind;
    rand qos_side_e side;
    rand int unsigned src;
    rand bit [AXI_ID_W-1:0] id;
    rand bit [M_AXI_ID_W-1:0] mid;
    rand bit [AXI_ADDR_W-1:0] addr;
    rand bit [AXI_LEN_W-1:0] len;
    rand bit [AXI_SIZE_W-1:0] size;
    rand bit [AXI_BURST_W-1:0] burst;
    rand bit [AXI_LOCK_W-1:0] lock;
    rand bit [AXI_CACHE_W-1:0] cache;
    rand bit [AXI_PROT_W-1:0] prot;
    rand bit [AXI_QOS_W-1:0] qos;
    rand bit [AXI_DATA_W-1:0] data;
    rand bit [AXI_STRB_W-1:0] strb;
    rand bit last;
    rand bit [1:0] resp;
    rand int unsigned idle_cycles;
    longint unsigned sample_cycle;
    bit default_sideband = 1'b1;

    constraint c_src { src < NUM_REQ; }
    constraint c_len { len inside {[0:15]}; }
    constraint c_idle { idle_cycles inside {[0:8]}; }
    constraint c_default_sideband {
      if (default_sideband) {
        size  == 3'd2;
        burst == 2'd1;
        lock  == '0;
        cache == '0;
        prot  == '0;
        qos   == src[AXI_QOS_W-1:0];
      }
    }

    `uvm_object_utils_begin(qos_axi_item)
      `uvm_field_enum(qos_kind_e, kind, UVM_DEFAULT)
      `uvm_field_enum(qos_side_e, side, UVM_DEFAULT)
      `uvm_field_int(src, UVM_DEFAULT)
      `uvm_field_int(id, UVM_DEFAULT)
      `uvm_field_int(mid, UVM_DEFAULT)
      `uvm_field_int(addr, UVM_DEFAULT)
      `uvm_field_int(len, UVM_DEFAULT)
      `uvm_field_int(size, UVM_DEFAULT)
      `uvm_field_int(burst, UVM_DEFAULT)
      `uvm_field_int(lock, UVM_DEFAULT)
      `uvm_field_int(cache, UVM_DEFAULT)
      `uvm_field_int(prot, UVM_DEFAULT)
      `uvm_field_int(qos, UVM_DEFAULT)
      `uvm_field_int(data, UVM_DEFAULT)
      `uvm_field_int(strb, UVM_DEFAULT)
      `uvm_field_int(last, UVM_DEFAULT)
      `uvm_field_int(resp, UVM_DEFAULT)
      `uvm_field_int(idle_cycles, UVM_DEFAULT)
      `uvm_field_int(sample_cycle, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "qos_axi_item");
      super.new(name);
      size  = 3'd2;
      burst = 2'd1;
      lock  = '0;
      cache = '0;
      prot  = '0;
      qos   = '0;
    endfunction
  endclass

  class qos_csr_item extends uvm_sequence_item;
    rand bit write;
    rand bit [7:0] addr;
    rand bit [31:0] data;
    bit [3:0] strb;
    bit [31:0] rdata;

    `uvm_object_utils_begin(qos_csr_item)
      `uvm_field_int(write, UVM_DEFAULT)
      `uvm_field_int(addr, UVM_DEFAULT)
      `uvm_field_int(data, UVM_DEFAULT)
      `uvm_field_int(strb, UVM_DEFAULT)
      `uvm_field_int(rdata, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "qos_csr_item");
      super.new(name);
      strb = 4'hf;
    endfunction
  endclass

  class qos_cfg extends uvm_object;
    `uvm_object_utils(qos_cfg)
    virtual qos_axi_if vif;
    int unsigned src_index;
    uvm_active_passive_enum is_active = UVM_ACTIVE;
    int unsigned ready_pct = 80;
    bit source_resp_ready_randomize = 0;
    int unsigned rready_pct = 100;
    int unsigned bready_pct = 100;

    function new(string name = "qos_cfg");
      super.new(name);
    endfunction
  endclass
