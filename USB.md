---
title: USB
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: 9c721b62
date: 2025-10-03 09:44:51
---
# USB

## USB2.0

### 枚举与配置

- 设备被连接到 USB 端口上，并得到检测。
- 集线器通过监控端口的电压来检测设备。集线器的 D+线和 D-线上带有下拉电阻，根据设备的速度，D+或 D-线上会带有上拉电阻。通过监控这些线上的电压变换，集线器检测设备是否得到连接。
- 这部分具体IAD描述符的参考<<iadclasscode_r10.pdf>> 2节 IAD Use Model Example 

![image-20240815170518414](42%20USB.assets/image-20240815170518414.png)

- 具体枚举配置过程,wireshark抓包不够准确,可以通过打印日志查看
- 方向分为设备到主机和主机到设备;意思是收到请求后执行的方向

1. 请求类型:Standard Device Request 方向:设备到主机 请求:GET_DESCRIPTOR 
    - wValue 
        - 描述符类型 :1 (设备描述符) 
        - 描述符索引: 0 (第一个描述符)
    - wIndex字段为字符串描述符指定语言ID

```log
[80 06 00 01 00 00 12 00]
[23:29:12 571]Setup: bmRequestType 0x80, bRequest 0x06, wValue 0x0100, wIndex 0x0000, wLength 0x0040
```

2. 回复设备描述符18字节,返回的是IAD描述符
    - bLength: 0x12 
    - bDescriptorType: 0x01 (设备描述符)
    - bcdUSB: 0x0200 (USB2.0)
    - bDeviceClass: 0xef (Miscellaneous Device Class)
    - bDeviceSubClass: 0x02 (Common Class Subclass)
    - bDeviceProtocol: 0x01 (Interface Association Descriptor)
    - bMaxPacketSize0: 0x40 (64 bytes)
    - idVendor: 0xffff (供应商 ID)
    - idProduct: 0xffff (产品 ID)
    - bcdDevice 0x0100 (设备版本号)
    - iManufacturer: 0x01 (制造商字符串描述符索引)
    - iProduct: 0x02 (产品字符串描述符索引)
    - iSerialNumber: 0x03 (序列号字符串描述符索引)
    - bNumConfigurations: 0x01 (配置数量)
```log
[12 01 00 02 ef 02 01 40 ff ff ff ff 00 01 01 02 03 01]
[23:29:12 573]EP0 send 18 bytes, 0 remained
```

3. 请求类型:Standard Device Request 方向:主机到设备 请求:SET_ADDRESS
    - wValue: 0x001d (地址为29)

```log
[23:29:12 631]Setup: bmRequestType 0x00, bRequest 0x05, wValue 0x001d, wIndex 0x0000, wLength 0x0000
[23:29:12 635]EP0 send 0 bytes, 0 remained
```

4. 请求类型:Standard Device Request 方向:设备到主机 请求:GET_DESCRIPTOR
    - wValue 
        - 描述符类型 :1 (设备描述符) 
        - 描述符索引: 0 (第一个描述符)
    - wIndex字段为字符串描述符指定语言ID

```log
[23:29:12 650]Setup: bmRequestType 0x80, bRequest 0x06, wValue 0x0100, wIndex 0x0000, wLength 0x0012
[23:29:12 653]EP0 send 18 bytes, 0 remained
```

5. 请求类型:Standard Device Request 方向:设备到主机 请求:GET_DESCRIPTOR
    - wValue 
        - 描述符类型 :2 (配置描述符)
        - 描述符索引: 0 (第一个描述符)
    - wIndex字段为字符串描述符指定语言ID
    - wLength: 0x004b (75 bytes)

```log
[80 06 00 02 00 00 4b 00]
[23:29:12 670]Setup: bmRequestType 0x80, bRequest 0x06, wValue 0x0200, wIndex 0x0000, wLength 0x004b
```

6. 回复描述符75字节
    1. 配置描述符
    - bLength: 0x09
    - bDescriptorType: 0x02 (配置描述符)
    - wTotalLength: 0x004b (配置描述符及其子描述符的总长度)
    - bNumInterfaces: 0x01 (接口数量)
    - bConfigurationValue: 0x01 (配置值)
    - bmAttributes: 0x80 (配置属性)
        - Bit 6: Self-powered 0:总线供电
        - Bit 5: Remote Wakeup 0:不支持远程唤醒
    - bMaxPower: 0x32 (最大功率 单位2mA) 100mA
    2. 接口描述符
    - bLength: 0x08
    - bDescriptorType: 0x0b (接口描述符)
    - bInterfaceNumber: 0x00 (接口号)
    - bInterfaceCount: 0x02 (接口数量)
    - bFunctionClass: 0x02 (Communication Device Class)
    - bFunctionSubClass: 0x02 (Abstract Control Model)
    - bFunctionProtocol: 0x01 (ITU-T V.250)
    - iFunction: 0x00 (接口描述符索引)
    3. 接口描述符
    - bLength: 0x09
    - bDescriptorType: 0x04 (接口描述符)
    - bInterfaceNumber: 0x00 (接口号)
    - bAlternateSetting: 0x00 (备用设置)
    - bNumEndpoints: 0x01 (端点数量)
    - bInterfaceClass: 0x02 (Communication Device Class)
    - bInterfaceSubClass: 0x02 (Abstract Control Model)
    - bInterfaceProtocol: 0x01 (ITU-T V.250)
    - iInterface: 0x02 (接口描述符索引)
    4. COMMUNICATION DESCRIPTOR
    - bLength: 0x05
    - bDescriptorType: 0x24 (CS_INTERFACE)
    - bDescriptorSubtype: 0x00 (Header Functional Descriptor)
    - bcdCDC: 0x0110 (CDC version 1.10)
    5. COMMUNICATION DESCRIPTOR
    - bLength: 0x05
    - bDescriptorType: 0x24 (CS_INTERFACE)
    - bDescriptorSubtype: 0x01 (Call Management Functional Descriptor)
    - bmCapabilities: 0x00
        - Call Management over Data Class Interface: Not supported
        - Call Management over Communication Class Interface: Not supported
    - bDataInterface: 0x01 (Data Class Interface)
    6. COMMUNICATION DESCRIPTOR
    - bLength: 0x04
    - bDescriptorType: 0x24 (CS_INTERFACE)
    - bDescriptorSubtype: 0x02 (Abstract Control Management Functional Descriptor)
    - bmCapabilities: 0x02
        - Comm Features Combinations: Not supported
        - Line Coding and Serial State: Supported
        - Send Break: Not supported
        - Network Connection: Not supported
    7. COMMUNICATION DESCRIPTOR
    - bLength: 0x05
    - bDescriptorType: 0x24 (CS_INTERFACE)
    - bDescriptorSubtype: 0x06 (Union Functional Descriptor)
    - bControlInterface: 0x00 (Control Class Interface)
    - bSubordinateInterface0: 0x01 (Data Class Interface)
    8. ENDPOINT DESCRIPTOR
    - bLength: 0x07
    - bDescriptorType: 0x05 (ENDPOINT)
    - bEndpointAddress: 0x83 (Endpoint 3 IN)
        - Direction: IN
        - Number: 3
    - bmAttributes: 0x03 (Transfer type: Interrupt)
        - Transactions per microframe: 1 (0)
    - wMaxPacketSize: 0x0008 (8 bytes)
    - bInterval: 0x00 (Polling interval in (micro) frames)
    9. INTERFACE DESCRIPTOR
    - bLength: 0x09
    - bDescriptorType: 0x04 (INTERFACE)
    - bInterfaceNumber: 0x01 (Interface 1)
    - bAlternateSetting: 0x00 (Alternate setting 0)
    - bNumEndpoints: 0x02 (2 endpoints)
    - bInterfaceClass: 0x0a (Data Interface Class)
    - bInterfaceSubClass: 0x00 (No specific subclass)
    - bInterfaceProtocol: 0x00 (No specific protocol)
    - iInterface: 0x00 (No string descriptor)
    10. ENDPOINT DESCRIPTOR
    - bLength: 0x07
    - bDescriptorType: 0x05 (ENDPOINT)
    - bEndpointAddress: 0x02 (Endpoint 2 OUT)
        - Direction: OUT
        - Number: 2
    - bmAttributes: 0x02 (Transfer type: Bulk)
        - Transactions per microframe: 1 (0)
    - wMaxPacketSize: 0x0040 (64 bytes)
    - bInterval: 0x00 (Polling interval in (micro) frames)
    11. ENDPOINT DESCRIPTOR
    - bLength: 0x07
    - bDescriptorType: 0x05 (ENDPOINT)
    - bEndpointAddress: 0x81 (Endpoint 1 IN)
        - Direction: IN
        - Number: 1
    - bmAttributes: 0x02 (Transfer type: Bulk)
        - Transactions per microframe: 1 (0)
    - wMaxPacketSize: 0x0040 (64 bytes)
```log
[09 02 4b 00 02 01 00 80 32]
[08 0b 00 02 02 02 01 00]
[09 04 00 00 01 02 02 01 02]
[05 24 00 10 01]
[05 24 01 00 01]
[04 24 02 02]
[05 24 06 00 01]
[07 05 83 03 08 00 0a]
[09 04 01 00 02 0a 00 00 00]
[07 05 02 02 40 00 00]
[07 05 81 02 40 00 00]
[23:29:12 673]EP0 send 64 bytes, 11 remained
[23:29:12 673]EP0 send 11 bytes, 0 remained
```

7. 请求类型:Standard Device Request 方向:设备到主机 请求:GET_DESCRIPTOR
    - wValue 
        - 描述符类型 :3 (字符串描述符) 
        - 描述符索引: 3 (第3个描述符)
    - wIndex字段为字符串描述符指定语言ID 0x0409 (英文)

```log
[80 06 02 03 09 04 26 00]
[23:29:12 685]Setup: bmRequestType 0x80, bRequest 0x06, wValue 0x0303, wIndex 0x0409, wLength 0x00ff
```

- 回复字符串描述符22字节
    - bLength: 0x16
    - bDescriptorType: 0x03 (字符串描述符)
    - bString: "2022123456"
```log
[16 03 32 00 32 00 32 00 31 00 32 00 33 00 34 00 35 00 36 00]
[23:29:12 685]EP0 send 22 bytes, 0 remained
```

8. 请求类型:Standard Device Request 方向:设备到主机 请求:GET_DESCRIPTOR
    - wValue 
        - 描述符类型 :3 (字符串描述符) 
        - 描述符索引: 0 (第0个描述符)
    - wIndex字段为字符串描述符指定语言ID 0x0000

```log
[23:29:12 695]Setup: bmRequestType 0x80, bRequest 0x06, wValue 0x0300, wIndex 0x0000, wLength 0x00ff
```

- 回复字符串描述符4字节
    - bLength: 0x04
    - bDescriptorType: 0x03 (字符串描述符)
    - bString: 0x0409 (英文)
```log
[04 03 09 04]
[23:29:12 697]EP0 send 4 bytes, 0 remained
```

9. 请求类型:Standard Device Request 方向:设备到主机 请求:GET_DESCRIPTOR
    - wValue 
        - 描述符类型 :3 (字符串描述符) 
        - 描述符索引: 2 (第2个描述符)
    - wIndex字段为字符串描述符指定语言ID 0x0409 (英文)

```log
[23:29:12 706]Setup: bmRequestType 0x80, bRequest 0x06, wValue 0x0302, wIndex 0x0409, wLength 0x00ff
```

- 回复字符串描述符38字节
    - bLength: 0x26
    - bDescriptorType: 0x03 (字符串描述符)
    - bString: "CherryUSB CDC DEMO"
```log
[26 03 43 00 68 00 65 00 72 00 72 00 79 00 55 00 53 00 42 00 20 00 43 00 44 00 43 00 20 00 44 00 45 00 4d 00 4f 00]
[23:29:12 706]EP0 send 38 bytes, 0 remained
```

10. 请求类型:Standard Device Request 方向:设备到主机 请求:GET_DESCRIPTOR
    - wValue 
        - 描述符类型 :06 (设备限定描述符)
        - 描述符索引: 0 (第0个描述符)
- 没有该描述符,回复STALL

```log
[23:29:12 719]Setup: bmRequestType 0x80, bRequest 0x06, wValue 0x0600, wIndex 0x0000, wLength 0x000a
```

11. 请求类型:Standard Device Request 方向:设备到主机 请求:SET_CONFIGURATION
    - wValue: 0x0001 (配置为1)

- 配置对应端点,回复配置状态
    1. 配置0x03端点方向为OUT,类型为中断,最大包大小为8
    2. 配置0x02端点方向为OUT,类型为批量,最大包大小为64
    3. 配置0x01端点方向为IN,类型为批量,最大包大小为64

```log
[23:29:12 773]Setup: bmRequestType 0x00, bRequest 0x09, wValue 0x0001, wIndex 0x0000, wLength 0x0000
[23:29:12 782]Open ep:0x83 type:3 mps:8
[23:29:12 782]Open ep:0x02 type:2 mps:64
[23:29:12 790]Open ep:0x81 type:2 mps:64
[23:29:12 790]EP0 send 0 bytes, 0 remained
```

12. 请求类型: Class Interface Request 方向:设备到主机 请求:GET_LINE_CODING
    - wValue: 0x0000
    - wIndex: 0x0000
    - wLength: 0x0007
    - bRequest 0x21

- 回复波特率:2000000,停止位:1,校验位:0,数据位:8

```log
[a1 21 00 00 00 00 07 00]
[23:29:12 845]Setup: bmRequestType 0xa1, bRequest 0x21, wValue 0x0000, wIndex 0x0000, wLength 0x0007
[23:29:12 849]CDC Class request: bRequest 0x21
[23:29:12 852]Get intf:0 linecoding 2000000 0 0 8
[80 84 1e 00 00 00 08]
[23:29:12 855]EP0 send 7 bytes, 0 remained
```

13.  请求类型: Class Interface Request 方向:设备到主机 请求:SET_CONTROL_LINE_STATE
    - wValue: 0x0000
    - wIndex: 0x0000
    - wLength: 0x0007
    - bRequest 0x20

- 设置DTR和RTS

```log
[21 22 00 00 00 00 00 00]
[23:29:12 877]Setup: bmRequestType 0x21, bRequest 0x22, wValue 0x0000, wIndex 0x0000, wLength 0x0000
[23:29:12 880]CDC Class request: bRequest 0x22
[23:29:12 885]Set intf:0 DTR 0x0,RTS 0x0
[23:29:12 887]EP0 send 0 bytes, 0 remained
```

14. 请求类型: Class Interface Request 方向:主机到设备 请求:SET_LINE_CODING
    - wValue: 0x0000
    - wIndex: 0x0000
    - wLength: 0x0007
    - bRequest 0x20

- 执行接收,配置波特率:2000000,停止位:1,校验位:0,数据位:8

```log
[23:29:12 897]Setup: bmRequestType 0x21, bRequest 0x20, wValue 0x0000, wIndex 0x0000, wLength 0x0007
[23:29:12 901]Start reading 7 bytes from ep0
[80 84 1e 00 00 00 08]
[23:29:12 903]EP0 recv 7 bytes, 0 remained
[23:29:12 912]CDC Class request: bRequest 0x20
[23:29:12 912]Set intf:0 linecoding <2000000 8 N 1>
[23:29:12 914]EP0 send 0 bytes, 0 remained
```

15. 请求类型: Class Interface Request 方向:主机到设备 请求:SET_CONTROL_LINE_STATE
    - wValue: 0x0002
    - wIndex: 0x0000
    - wLength: 0x0000
    - bRequest 0x22

- 设置DTR和RTS(串口助手开启关闭串口发送此命令,MCU可通过该命令实现同步开启输出或关闭)
    - DTR:0
    - RTS:1

```log
[23:29:18 841] [I/USB] Setup: bmRequestType 0x21, bRequest 0x22, wValue 0x0002, wIndex 0x0000, wLength 0x0000
[23:29:18 846] [D/USB] CDC Class request: bRequest 0x22
[23:29:18 849] [D/USB] Set intf:0 DTR 0x0,RTS 0x1
[23:29:18 853] [D/USB] EP0 send 0 bytes, 0 remained
```

### Endpoint

```c
/** Standard Endpoint Descriptor */
struct usb_endpoint_descriptor {
    uint8_t bLength;          /* Descriptor size in bytes = 7 */
    uint8_t bDescriptorType;  /* ENDPOINT descriptor type = 5 */
    uint8_t bEndpointAddress; /* Endpoint # 0 - 15 | IN/OUT */
    uint8_t bmAttributes;     /* Transfer type */
    uint16_t wMaxPacketSize;  /* Bits 10:0 = max. packet size */
    uint8_t bInterval;        /* Polling interval in (micro) frames */
} __PACKED;
```

- bLength: 描述符长度 7 字节
- bDescriptorType: 描述符类型 5(端点描述符)
- bEndpointAddress: 8位,低7位为端点号,最高位为方向,0表示OUT,1表示IN
- bmAttributes: 属性

位1 . .0:传输类型:00 =控制;01 =同步;10 =批量;11 =中断
如果不是等时端点，第5位…2为预留值，必须设置为0。如果是等时的，则定义如下:
位3 . .2:同步类型:00 =不同步;01 =异步;10 =自适应;11 =同步
Bits 5..4:使用类型:00 =数据端点;01 =反馈端点;10 =隐式反馈数据端点;11 =保留
所有其他的位被保留，必须重置为零。保留位必须被主机忽略。

- wMaxPacketSize: 最大包大小
对于所有端点，第10位…0指定最大数据包大小(以字节为单位)。

- bInterval: 传输间隔
数据传输轮询端点的时间间隔。
对于全速/低速中断端点，该字段的取值范围是1 ~ 255。

### Device Requests
- 所有USB设备在设备的默认控制管道上响应来自主机的请求。这些请求是使用控制传输发出的。请求和请求的参数在安装包中发送到设备。主机负责建立表9-2所示字段中传递的值。每个安装包有8个字节

| 偏移 | 字段          | 大小 | 值              | 说明                                                         |
| ---- | ------------- | ---- | --------------- | ------------------------------------------------------------ |
| 0    | bmRequestType | 1    | Bitmap          | D7:数据传输方向<br/>      0 =主机到设备1 =设备到主机<br/>D6……5:类型<br/>      0 =标准<br/>      1 =类别<br/>      2 =供应商<br/>      3 =保留<br/>D4……0:接收方<br/>0 =设备<br/>1 =接口<br/>2 =终端<br/>3 =其他<br/>4…31 =保留 |
| 1    | bRequest      | 1    | Value           | 具体要求(参见表9-3)                                          |
| 2    | wValue        | 2    | Value           |                                                              |
| 4    | wIndex        | 2    | Index or Offset |                                                              |
| 6    | wLength       | 2    | Count           | 如果有数据阶段，要传输的字节数                               |

- 标准设备请求

![image-20240813175153704](42%20USB.assets/image-20240813175153704.png)

![image-20240815104039529](42%20USB.assets/image-20240815104039529.png)

### 描述符

#### 标准设备描述符

- 参考<<USB2.0.pdf>> 9.6.1节

```c
/** Standard Device Descriptor 
 * @bcdUSB: USB 版本号
 * @bDeviceClass: 设备类代码
 * @bDeviceSubClass: 设备子类代码
 * @bDeviceProtocol: 设备协议代码
 * @bMaxPacketSize0: 最大包大小 8/16/32/64 bytes 0x40 = 64
 * @idVendor: 供应商 ID
 * @idProduct: 产品 ID
 * @bcdDevice: 设备版本号
 * @bNumConfigurations: 配置数量
*/
#define USB_DEVICE_DESCRIPTOR_INIT(bcdUSB, bDeviceClass, bDeviceSubClass, bDeviceProtocol, idVendor, idProduct, bcdDevice, bNumConfigurations) \
    0x12,                       /* bLength */                                                                                              \
    USB_DESCRIPTOR_TYPE_DEVICE, /* bDescriptorType */                                                                                      \
    WBVAL(bcdUSB),              /* bcdUSB */                                                                                               \
    bDeviceClass,               /* bDeviceClass */                                                                                         \
    bDeviceSubClass,            /* bDeviceSubClass */                                                                                      \
    bDeviceProtocol,            /* bDeviceProtocol */                                                                                      \
    0x40,                       /* bMaxPacketSize */                                                                                       \
    WBVAL(idVendor),            /* idVendor */                                                                                             \
    WBVAL(idProduct),           /* idProduct */                                                                                            \
    WBVAL(bcdDevice),           /* bcdDevice */                                                                                            \
    USB_STRING_MFC_INDEX,       /* iManufacturer */                                                                                        \
    USB_STRING_PRODUCT_INDEX,   /* iProduct */                                                                                             \
    USB_STRING_SERIAL_INDEX,    /* iSerial */                                                                                              \
    bNumConfigurations          /* bNumConfigurations */
```

![image-20240815155536119](42%20USB.assets/image-20240815155536119.png)

#### 标准配置描述符

- `bConfigurationValue` 字段指示设备固件中定义的配置编号。客户端驱动程序使用该数字值来选择活动配置。

```c
/*
    * @wTotalLength: 配置描述符及其子描述符的总长度
    * @bNumInterfaces: 接口数量
    * @bConfigurationValue: 配置值
    * @bmAttributes: 配置属性
        * Bit 7: Reserved (set to one)
        * Bit 6: Self-powered 1:设备自供电 0:总线供电
        * Bit 5: Remote Wakeup 1:支持远程唤醒 0:不支持远程唤醒
        * Bits 4..0: Reserved (reset to zero)
    * @bMaxPower: 最大功率 单位2mA
*/
#define USB_CONFIG_DESCRIPTOR_INIT(wTotalLength, bNumInterfaces, bConfigurationValue, bmAttributes, bMaxPower) \
    0x09,                              /* bLength */                                                       \
    USB_DESCRIPTOR_TYPE_CONFIGURATION, /* bDescriptorType */                                               \
    WBVAL(wTotalLength),               /* wTotalLength */                                                  \
    bNumInterfaces,                    /* bNumInterfaces */                                                \
    bConfigurationValue,               /* bConfigurationValue */                                           \
    0x00,                              /* iConfiguration */                                                \
    bmAttributes,                      /* bmAttributes */                                                  \
    USB_CONFIG_P
```

#### IAD描述符

```c
/*
    * @bFirstInterface: 第一个接口号
    * @bInterfaceCount: 接口数量
    * @bFunctionClass: 设备类代码
    * @bFunctionSubClass: 设备子类代码
    * @bFunctionProtocol: 设备协议代码
*/
#define USB_IAD_INIT(bFirstInterface, bInterfaceCount, bFunctionClass, bFunctionSubClass, bFunctionProtocol) \
    0x08,                                      /* bLength */                                             \
    USB_DESCRIPTOR_TYPE_INTERFACE_ASSOCIATION, /* bDescriptorType */                                     \
    bFirstInterface,                           /* bFirstInterface */                                     \
    bInterfaceCount,                           /* bInterfaceCount */                                     \
    bFunctionClass,                            /* bFunctionClass */                                      \
    bFunctionSubClass,                         /* bFunctionSubClass */                                   \
    bFunctionProtocol,                         /* bFunctionProtocol */                                   \
    0x00                                       /* iFunction */
```

#### 标准接口描述符

```c
/*
* @bInterfaceNumber: 接口号 从0开始
* @bAlternateSetting: 备用设置 用于为先前字段中标识的接口选择此备用设置
* @bNumEndpoints: 端点数量 此接口使用的端点数(不包括端点0)。如果该值为零，则该接口只使用默认控制管道。
* @bInterfaceClass: 设备类代码
* @bInterfaceSubClass: 设备子类代码
* @bInterfaceProtocol: 设备协议代码
* @iInterface: 接口描述符索引
*/
#define USB_INTERFACE_DESCRIPTOR_INIT(bInterfaceNumber, bAlternateSetting, bNumEndpoints,                  \
                                      bInterfaceClass, bInterfaceSubClass, bInterfaceProtocol, iInterface) \
    0x09,                          /* bLength */                                                       \
    USB_DESCRIPTOR_TYPE_INTERFACE, /* bDescriptorType */                                               \
    bInterfaceNumber,              /* bInterfaceNumber */                                              \
    bAlternateSetting,             /* bAlternateSetting */                                             \
    bNumEndpoints,                 /* bNumEndpoints */                                                 \
    bInterfaceClass,               /* bInterfaceClass */                                               \
    bInterfaceSubClass,            /* bInterfaceSubClass */                                            \
    bInterfaceProtocol,            /* bInterfaceProtocol */                                            \
    iInterface                     /* iInterface */
```

#### 标准端点描述符

```c
#define USB_ENDPOINT_DESCRIPTOR_INIT(bEndpointAddress, bmAttributes, wMaxPacketSize, bInterval) \
    0x07,                         /* bLength */                                             \
    USB_DESCRIPTOR_TYPE_ENDPOINT, /* bDescriptorType */                                     \
    bEndpointAddress,             /* bEndpointAddress */                                    \
    bmAttributes,                 /* bmAttributes */                                        \
    WBVAL(wMaxPacketSize),        /* wMaxPacketSize */                                      \
    bInterval                     /* bInterval */
```

#### 字符串描述符

- 字符串描述符是可选的。如前所述，如果设备不支持字符串描述符，则必须将设备、配置和接口描述符中对字符串描述符的所有引用重置为零。
- 字符串描述符使用由统一码标准定义的统一码编码,所有语言的字符串索引为零返回一个字符串描述符，该描述符包含设备支持的双字节LANGID代码数组。USB设备可以省略所有的字符串描述符。省略所有字符串描述符的USB设备必须不返回LANGID代码数组。

```c
#define USB_LANGID_INIT(id)                           \
    0x04,                           /* bLength */     \
    USB_DESCRIPTOR_TYPE_STRING, /* bDescriptorType */ \
    WBVAL(id)                   /* wLangID0 */
```

# cherryUSB

## 杂项

- USB_MEM_ALIGNX: 用于指定内存对齐方式,用`CONFIG_USB_ALIGN_SIZE`配置,默认4字节对齐
```c
#define USB_MEM_ALIGNX __attribute__((aligned(CONFIG_USB_ALIGN_SIZE)))
```

- USB_NOCACHE_RAM_SECTION: 用于指定数据存储在无缓存RAM中,用于DMA传输
```c
/* attribute data into no cache ram */
#define USB_NOCACHE_RAM_SECTION __attribute__((section(".noncacheable")))
```

- `CONFIG_USBDEV_ADVANCE_DESC`: `usbd_desc_register`当前 API 仅支持一种速度，如果需要更高级的速度切换功能，请开启 CONFIG_USBDEV_ADVANCE_DESC，并且包含了下面所有描述符注册功能

# dwc2

## usb_dc_init

- 初始化 usb device controller 寄存器，设置 usb 引脚、时钟、中断等等
1. 软断开
- 供电状态可借助软断开功能通过软件退出。将设备控制寄存器中的软断开位（OTG_DCTL中的 SDIS 位）置 1 即可移除 DP 上拉电阻，此时尽管没有从主机端口实际拔出 USB 电缆， 但主机端仍会发生设备断开检测中断.
2. 关闭全局中断
3. B会话有效覆盖使能
- 由 OTG_HS 模块控制的 DP/DM 集成上拉电阻和下拉电阻，具体使能哪种电阻取决于设备的当前角色。作为外设使用时，只要检测到 VBUS 为有效电平（B 会话有效），立即使能 DP 上拉电阻，以告知全速设备的连接。
- VBUS 输入检测到 B 会话有效电压，就会使 USB 设备进入供电状态（请参见 USB2.0 第 9.1 部分）。
- 如果检测到 VBUS 降至 B 会话有效电压以下（例如，因电源干扰或主机端口关闭引发），OTG_HS 将自动断 开连接并生成检测到会话结束中断（OTG_GOTGINT 中的 SEDET 位），指示 OTG_HS 已 退出供电状态。
4. 全速串行收发器选择
0：USB 2.0 外部 ULPI 高速 PHY。
1：USB 1.1 全速串行收发器。
5. 复位
6. 强制设备模式
- 向该位写入 1 时，可将模块强制为设备模式，而无需考虑 OTG_ID 输入引脚。
- 0：正常模式1：强制设备模式
- 将强制位置 1 后，应用程序必须等待至少 25 ms 后更改方可生效。
7. 重启 PHY 时钟
8. 设备速度配置
- 指示应用程序要求模块进行枚举所采用的速度，或应用程序支持的最大速度。但是，实际总线速度只有在完成 chirp 序列后才能确定，同时此速度基于与模块连接的 USB 主机的速度。
- 00：高速01：使用 HS 进行全速通信;10：保留;11：使用内置 FS PHY 进行全速通信
9. 清除中断标志
10. 配置fifo
- 0X10刷新所有发送FIFO
- 通常建议在重新配置 FIFO 时进行刷新。还建议在设备端点禁止期间进行 FIFO 刷新。应用程序必须等待模块将此位清零，才能执行任意操作。该位需要八个时钟来清零（使用较慢的phy_clk 或 hclk 时钟）。
- 应用程序可使用此位刷新整个 Rx FIFO，但必须首先确保模块当前未在处理事务。只有在确认模块当前未对 Rx FIFO 执行读写操作后，应用程序方可对此位执行写操作。应用程序必须等到此位清零后，方可执行其它操作。通常需要等待 8 个时钟周期（以 PHY 或 
AHB 时钟中最慢的为准）。

11. 使能中断,关闭软断开

```c
int usb_dc_init(uint8_t busid)
{
    memset(&g_dwc2_udc, 0, sizeof(struct dwc2_udc));

    usb_dc_low_level_init();    // 初始化 usb 设备控制器

    USB_OTG_DEV->DCTL |= USB_OTG_DCTL_SDIS;         //软件断开USB连接
    USB_OTG_GLB->GAHBCFG &= ~USB_OTG_GAHBCFG_GINT;  //关闭全局中断
    // STM32 cfg usb
    /* B-peripheral session valid override enable */
    USB_OTG_GLB->GOTGCTL |= USB_OTG_GOTGCTL_BVALOEN;    // 使能VBUS检查
    USB_OTG_GLB->GOTGCTL |= USB_OTG_GOTGCTL_BVALOVAL;
    /* Select FS Embedded PHY */
    USB_OTG_GLB->GUSBCFG |= USB_OTG_GUSBCFG_PHYSEL;     // 选择USB2.0全速PHY
    /* Reset after a PHY select */
    ret = dwc2_reset();
    /* Force Device Mode*/
    dwc2_set_mode(USB_OTG_MODE_DEVICE);
    /* Restart the Phy Clock */
    USB_OTG_PCGCCTL = 0U;
    /* Device speed configuration */
    USB_OTG_DEV->DCFG |= USB_OTG_SPEED_HIGH_IN_FULL;

    //......

    ret = dwc2_flush_txfifo(0x10U); //刷新所有发送FIFO
    ret = dwc2_flush_rxfifo();

    USB_OTG_GLB->GAHBCFG |= USB_OTG_GAHBCFG_GINT;
    USB_OTG_DEV->DCTL &= ~USB_OTG_DCTL_SDIS;
}
```

## usb_dc_low_level_init

- stm32: cubemx 生成的代码copy msp_init既可
1. 初始化USB时钟
2. 初始化USB引脚
3. 初始化USB中断

## USBD_IRQHandler

- 要将 rc_w1 类型中断状态位清零，应用程序必须向该位写入 1。

### USB复位 USB_OTG_GINTSTS_USBRST

1. 清除USB复位中断标志
2. 刷新所有FIFO
3. 使能0端点,发送NACK;禁用非0端点,发送NACK
4. 解除0端点中断屏蔽


```c
    USB_OTG_GLB->GINTSTS |= USB_OTG_GINTSTS_USBRST; //清除USB复位中断标志
    USB_OTG_DEV->DCTL &= ~USB_OTG_DCTL_RWUSIG;      //清除远程唤醒信号
    //刷新所有FIFO
    dwc2_flush_txfifo(0x10U);
    dwc2_flush_rxfifo();

    for (uint8_t i = 0U; i < CONFIG_USBDEV_EP_NUM; i++) {
        if (i == 0U) {  //使能0端点,发送ACK
            USB_OTG_INEP(i)->DIEPCTL = USB_OTG_DIEPCTL_SNAK;
            USB_OTG_OUTEP(i)->DOEPCTL = USB_OTG_DOEPCTL_SNAK;
        } else {    //禁用非0端点,发送NACK
            if (USB_OTG_INEP(i)->DIEPCTL & USB_OTG_DIEPCTL_EPENA) {
                USB_OTG_INEP(i)->DIEPCTL = (USB_OTG_DIEPCTL_EPDIS | USB_OTG_DIEPCTL_SNAK);
            } else {
                USB_OTG_INEP(i)->DIEPCTL = 0;
            }
            if (USB_OTG_OUTEP(i)->DOEPCTL & USB_OTG_DOEPCTL_EPENA) {
                USB_OTG_OUTEP(i)->DOEPCTL = (USB_OTG_DOEPCTL_EPDIS | USB_OTG_DOEPCTL_SNAK);
            } else {
                USB_OTG_OUTEP(i)->DOEPCTL = 0;
            }
        }
        USB_OTG_INEP(i)->DIEPTSIZ = 0U;         //清除发送端点传输大小
        USB_OTG_INEP(i)->DIEPINT = 0xFBFFU;     //清除发送端点中断标志
        USB_OTG_OUTEP(i)->DOEPTSIZ = 0U;        //清除接收端点传输大小
        USB_OTG_OUTEP(i)->DOEPINT = 0xFBFFU;    //清除接收端点中断标志
    }

    USB_OTG_DEV->DAINTMSK |= 0x10001U;          //解除0端点中断屏蔽

    USB_OTG_DEV->DOEPMSK = USB_OTG_DOEPMSK_STUPM |  //OUT端点使能SETUP阶段完成中断
                            USB_OTG_DOEPMSK_XFRCM;  //OUT端点使能传输完成中断

    USB_OTG_DEV->DIEPMSK = USB_OTG_DIEPMSK_XFRCM;   //IN端点使能传输完成中断

    memset(&g_dwc2_udc, 0, sizeof(struct dwc2_udc));
    usbd_event_reset_handler(0);        //USB复位事件处理
    /* Start reading setup */
    dwc2_ep0_start_read_setup((uint8_t *)&g_dwc2_udc.setup);
```

### USB OUT端点中断 USB_OTG_GINTSTS_OEPINT

1. 接收到OUT0端点中断
- xfer_len = 0,没接收到,再次接收;`dwc2_ep0_start_read_setup`
- `usbd_event_ep_out_complete_handler`

2. 接收其他OUT端点中断
- 执行`usbd_event_ep_out_complete_handler`处理接收完成事件

3. 接收到setup完成中断 `USB_OTG_DOEPINT_STUP`
- `usbd_event_ep0_setup_complete_handler`
- STUP：SETUP 阶段完成 (SETUP phase done):仅适用于控制 OUT 端点。指示控制端点的 SETUP 阶段已完成，当前控制传输中不再接收到连续的 SETUP 数据包。在此中断上，应用程序可以对接收到的 SETUP 数据包进行解码。

4. setup流程
- 初始化完成触发RESET中断执行`dwc2_ep0_start_read_setup`
- DMA接收或`USB_OTG_GINTSTS_RXFLVL`中断触发接收完成,执行`dwc2_ep_read((uint8_t *)&g_dwc2_udc.setup, read_count);`完成SETUP包接收
- 主机发送SETUP包,触发SETUP中断,执行`usbd_event_ep0_setup_complete_handler`
- 接收完成触发XFRC中断,执行`usbd_event_ep_out_complete_handler`

```c
    ep_idx = 0;
    ep_intr = dwc2_get_outeps_intstatus();
    while (ep_intr != 0U) {
        if ((ep_intr & 0x1U) != 0U) {                       //获取是哪个端点产生的中断
            epint = dwc2_get_outep_intstatus(ep_idx);       //获取端点中断状态
            uint32_t DoepintReg = USB_OTG_OUTEP(ep_idx)->DOEPINT;
            USB_OTG_OUTEP(ep_idx)->DOEPINT = DoepintReg;    //清除中断标志

            if ((epint & USB_OTG_DOEPINT_XFRC) == USB_OTG_DOEPINT_XFRC) {
                if (ep_idx == 0) {
                    if (g_dwc2_udc.out_ep[ep_idx].xfer_len == 0) {
                        /* Out status, start reading setup */
                        dwc2_ep0_start_read_setup((uint8_t *)&g_dwc2_udc.setup);
                    } else {
                        g_dwc2_udc.out_ep[ep_idx].actual_xfer_len = g_dwc2_udc.out_ep[ep_idx].xfer_len - ((USB_OTG_OUTEP(ep_idx)->DOEPTSIZ) & USB_OTG_DOEPTSIZ_XFRSIZ);
                        g_dwc2_udc.out_ep[ep_idx].xfer_len = 0;
                        usbd_event_ep_out_complete_handler(0, 0x00, g_dwc2_udc.out_ep[ep_idx].actual_xfer_len);  //执行usbd_event_ep0_out_complete_handler
                    }
                } else {
                    g_dwc2_udc.out_ep[ep_idx].actual_xfer_len = g_dwc2_udc.out_ep[ep_idx].xfer_len - ((USB_OTG_OUTEP(ep_idx)->DOEPTSIZ) & USB_OTG_DOEPTSIZ_XFRSIZ);
                    g_dwc2_udc.out_ep[ep_idx].xfer_len = 0;
                    usbd_event_ep_out_complete_handler(0, ep_idx, g_dwc2_udc.out_ep[ep_idx].actual_xfer_len);
                }
            }

            if ((epint & USB_OTG_DOEPINT_STUP) == USB_OTG_DOEPINT_STUP) {
                usbd_event_ep0_setup_complete_handler(0, (uint8_t *)&g_dwc2_udc.setup);
            }
        }
        ep_intr >>= 1U;
        ep_idx++;
    }
```

### USB RxFIFO nonempty 中断 USB_OTG_GINTSTS_RXFLVL
1. 屏蔽接收中断
2. 是数据包,传入`xfer_buf`
3. 是SETUP包,传入`g_dwc2_udc.setup`
4. 解除接收中断屏蔽

```c
    USB_MASK_INTERRUPT(USB_OTG_GLB, USB_OTG_GINTSTS_RXFLVL);

    temp = USB_OTG_GLB->GRXSTSP;
    ep_idx = temp & USB_OTG_GRXSTSP_EPNUM;

    if (((temp & USB_OTG_GRXSTSP_PKTSTS) >> USB_OTG_GRXSTSP_PKTSTS_Pos) == STS_DATA_UPDT) {
        //读取数据包
        read_count = (temp & USB_OTG_GRXSTSP_BCNT) >> 4;
        if (read_count != 0) {
            dwc2_ep_read(g_dwc2_udc.out_ep[ep_idx].xfer_buf, read_count);
            g_dwc2_udc.out_ep[ep_idx].xfer_buf += read_count;
        }
    } else if (((temp & USB_OTG_GRXSTSP_PKTSTS) >> USB_OTG_GRXSTSP_PKTSTS_Pos) == STS_SETUP_UPDT) {
        //读取SETUP包
        read_count = (temp & USB_OTG_GRXSTSP_BCNT) >> 4;
        dwc2_ep_read((uint8_t *)&g_dwc2_udc.setup, read_count);
    } else {
        /* ... */
    }
    USB_UNMASK_INTERRUPT(USB_OTG_GLB, USB_OTG_GINTSTS_RXFLVL);
```

### USB IN端点中断 USB_OTG_GINTSTS_IEPINT

1. USB_OTG_DIEPINT_TXFE 触发,执行`dwc2_tx_fifo_empty_procecss`
2. USB_OTG_DIEPINT_XFRC 触发,执行`usbd_event_ep_in_complete_handler`

```c
    while (ep_intr != 0U) {
        if ((ep_intr & 0x1U) != 0U) {
            epint = dwc2_get_inep_intstatus(ep_idx);
            uint32_t DiepintReg = USB_OTG_INEP(ep_idx)->DIEPINT;
            USB_OTG_INEP(ep_idx)->DIEPINT = DiepintReg;

            if ((epint & USB_OTG_DIEPINT_XFRC) == USB_OTG_DIEPINT_XFRC) {
                if (ep_idx == 0) {
                    g_dwc2_udc.in_ep[ep_idx].actual_xfer_len = g_dwc2_udc.in_ep[ep_idx].xfer_len - ((USB_OTG_INEP(ep_idx)->DIEPTSIZ) & USB_OTG_DIEPTSIZ_XFRSIZ);
                    g_dwc2_udc.in_ep[ep_idx].xfer_len = 0;
                    usbd_event_ep_in_complete_handler(0, 0x80, g_dwc2_udc.in_ep[ep_idx].actual_xfer_len);   //执行usbd_event_ep0_in_complete_handler

                    if (g_dwc2_udc.setup.wLength && ((g_dwc2_udc.setup.bmRequestType & USB_REQUEST_DIR_MASK) == USB_REQUEST_DIR_OUT)) {
                        /* In status, start reading setup */
                        dwc2_ep0_start_read_setup((uint8_t *)&g_dwc2_udc.setup);
                    } else if (g_dwc2_udc.setup.wLength == 0) {
                        /* In status, start reading setup */
                        dwc2_ep0_start_read_setup((uint8_t *)&g_dwc2_udc.setup);
                    }
                } else {
                    g_dwc2_udc.in_ep[ep_idx].actual_xfer_len = g_dwc2_udc.in_ep[ep_idx].xfer_len - ((USB_OTG_INEP(ep_idx)->DIEPTSIZ) & USB_OTG_DIEPTSIZ_XFRSIZ);
                    g_dwc2_udc.in_ep[ep_idx].xfer_len = 0;
                    usbd_event_ep_in_complete_handler(0, ep_idx | 0x80, g_dwc2_udc.in_ep[ep_idx].actual_xfer_len);
                }
            }
            if ((epint & USB_OTG_DIEPINT_TXFE) == USB_OTG_DIEPINT_TXFE) {
                dwc2_tx_fifo_empty_procecss(ep_idx);
            }
        }
        ep_intr >>= 1U;
        ep_idx++;
```

## usbd_ep_open

- USBAEP：USB 活动端点 (USB active endpoint)
指示此端点在当前配置和接口中是否激活。检测到 USB 复位后，模块会为所有端点（端点0 除外）将此位清零。接收到 SetConfiguration 和 SetInterface 命令后，应用程序必须相应地对端点寄存器进行编程并将此位置 1。
- SNPM：监听模式 (Snoop mode)
此位用于将端点配置为监听模式。在监听模式下，模块不会在将 OUT 数据包传输到应用存储区前检查其是否正确。

```c
int usbd_ep_open(uint8_t busid, const struct usb_endpoint_descriptor *ep)
{
    uint8_t ep_idx = USB_EP_GET_IDX(ep->bEndpointAddress);

    if (ep_idx > (CONFIG_USBDEV_EP_NUM - 1)) {
        USB_LOG_ERR("Ep addr %02x overflow\r\n", ep->bEndpointAddress);
        return -1;
    }

    if (USB_EP_DIR_IS_OUT(ep->bEndpointAddress)) {
        g_dwc2_udc.out_ep[ep_idx].ep_mps = USB_GET_MAXPACKETSIZE(ep->wMaxPacketSize);
        g_dwc2_udc.out_ep[ep_idx].ep_type = USB_GET_ENDPOINT_TYPE(ep->bmAttributes);

        USB_OTG_DEV->DAINTMSK |= USB_OTG_DAINTMSK_OEPM & (uint32_t)(1UL << (16 + ep_idx));  //解除端点中断屏蔽

        if ((USB_OTG_OUTEP(ep_idx)->DOEPCTL & USB_OTG_DOEPCTL_USBAEP) == 0) {   //未激活此端点
            USB_OTG_OUTEP(ep_idx)->DOEPCTL |= (USB_GET_MAXPACKETSIZE(ep->wMaxPacketSize) & USB_OTG_DOEPCTL_MPSIZ) |
                                              ((uint32_t)USB_GET_ENDPOINT_TYPE(ep->bmAttributes) << 18) |
                                              USB_OTG_DIEPCTL_SD0PID_SEVNFRM |  //配置监听模式
                                              USB_OTG_DOEPCTL_USBAEP;   //激活此端点
        }
    } else {
        uint16_t fifo_size;
        if (ep_idx == 0) {
            fifo_size = (USB_OTG_GLB->DIEPTXF0_HNPTXFSIZ >> 16);
        } else {
            fifo_size = (USB_OTG_GLB->DIEPTXF[ep_idx - 1U] >> 16);
        }
        if ((fifo_size * 4) < USB_GET_MAXPACKETSIZE(ep->wMaxPacketSize)) {
            USB_LOG_ERR("Ep addr %02x fifo overflow\r\n", ep->bEndpointAddress);
            return -2;
        }

        g_dwc2_udc.in_ep[ep_idx].ep_mps = USB_GET_MAXPACKETSIZE(ep->wMaxPacketSize);
        g_dwc2_udc.in_ep[ep_idx].ep_type = USB_GET_ENDPOINT_TYPE(ep->bmAttributes);

        USB_OTG_DEV->DAINTMSK |= USB_OTG_DAINTMSK_IEPM & (uint32_t)(1UL << ep_idx);

        if ((USB_OTG_INEP(ep_idx)->DIEPCTL & USB_OTG_DIEPCTL_USBAEP) == 0) {
            USB_OTG_INEP(ep_idx)->DIEPCTL |= (USB_GET_MAXPACKETSIZE(ep->wMaxPacketSize) & USB_OTG_DIEPCTL_MPSIZ) |
                                             ((uint32_t)USB_GET_ENDPOINT_TYPE(ep->bmAttributes) << 18) | (ep_idx << 22) |
                                             USB_OTG_DIEPCTL_SD0PID_SEVNFRM |
                                             USB_OTG_DIEPCTL_USBAEP;
        }
        dwc2_flush_txfifo(ep_idx);
    }
    return 0;
}
```

## dwc2_ep0_start_read_setup

```c
static void dwc2_ep0_start_read_setup(uint8_t *psetup)
{
    USB_OTG_OUTEP(0U)->DOEPTSIZ = 0U;
    USB_OTG_OUTEP(0U)->DOEPTSIZ |= (USB_OTG_DOEPTSIZ_PKTCNT & (1U << 19));  //包数量
    USB_OTG_OUTEP(0U)->DOEPTSIZ |= (3U * 8U);   //包大小
    USB_OTG_OUTEP(0U)->DOEPTSIZ |= USB_OTG_DOEPTSIZ_STUPCNT;    //SETUP包

#ifdef CONFIG_USB_DWC2_DMA_ENABLE
    USB_OTG_OUTEP(0U)->DOEPDMA = (uint32_t)psetup;
    /* EP enable */
    USB_OTG_OUTEP(0U)->DOEPCTL |= USB_OTG_DOEPCTL_EPENA | USB_OTG_DOEPCTL_USBAEP;
#endif
}
```

## usbd_event_ep0_setup_complete_handler

1. 复制SETUP包
2. 判断缓存长度是否满足接收要求
3. 设置数据缓存
4. 通过安装的处理程序处理请求,具有数据阶段的请求,继续读取数据
5. 执行请求处理程序
6. 检查发送长度并设置
7. 复制数据到ep0_data_buf
8. 发送数据或状态到主机
9. 设置 zlp_flag 的目的是为了在这种情况下发送一个零长度包,让主机需要知道传输已经完成。

- 例外:情况
  1. `SET_CONFIGURATION`请求执行后,返回长度为0,则发送0长度包,将`req_data`设置为`ep0_data_buf`发送

- 例如
收到`80 06 00 01 00 00 12 00`,执行`usbd_get_descriptor`函数,发送设备描述符


```c
void usbd_event_ep0_setup_complete_handler(uint8_t busid, uint8_t *psetup)
{
    struct usb_setup_packet *setup = &g_usbd_core[busid].setup;
    uint8_t *buf;

    //复制SETUP包
    // 判断缓存长度是否满足接收要求

    g_usbd_core[busid].ep0_data_buf = g_usbd_core[busid].req_data;  //设置数据缓存
    g_usbd_core[busid].ep0_data_buf_residue = setup->wLength;
    g_usbd_core[busid].ep0_data_buf_len = setup->wLength;
    g_usbd_core[busid].zlp_flag = false;
    buf = g_usbd_core[busid].ep0_data_buf;  //设置数据缓存

    // 通过安装的处理程序处理请求,具有数据阶段的请求,继续读取数据
    if (setup->wLength && ((setup->bmRequestType & USB_REQUEST_DIR_MASK) == USB_REQUEST_DIR_OUT)) {
        USB_LOG_DBG("Start reading %d bytes from ep0\r\n", setup->wLength);
        usbd_ep_start_read(busid, USB_CONTROL_OUT_EP0, g_usbd_core[busid].ep0_data_buf, setup->wLength);
        return;
    }

    // 执行请求处理程序
    if (!usbd_setup_request_handler(busid, setup, &buf, &g_usbd_core[busid].ep0_data_buf_len)) {
        usbd_ep_set_stall(busid, USB_CONTROL_IN_EP0);   //请求处理失败,设置端点STALL
        return;
    }

    //检查发送长度并设置
    //如果buf数据与请求的数据不一致,复制数据到ep0_data_buf
    if (buf != g_usbd_core[busid].ep0_data_buf) {
        memcpy(g_usbd_core[busid].ep0_data_buf, buf, g_usbd_core[busid].ep0_data_buf_residue);
    }
    /* Send data or status to host */
    usbd_ep_start_write(busid, USB_CONTROL_IN_EP0, g_usbd_core[busid].ep0_data_buf, g_usbd_core[busid].ep0_data_buf_residue);
    // 设置 zlp_flag 的目的是为了在这种情况下发送一个零长度包,让主机需要知道传输已经完成。
    if ((setup->wLength > g_usbd_core[busid].ep0_data_buf_len) && (!(g_usbd_core[busid].ep0_data_buf_len % USB_CTRL_EP_MPS))) {
        g_usbd_core[busid].zlp_flag = true;
        USB_LOG_DBG("EP0 Set zlp\r\n");
    }
}
```

## usbd_ep_start_read

1. 确保数据地址是4字节对齐
2. 数据长度为0
- 数据长度为0,设置数据包数量为1,传输大小为端点最大包大小,使能端点
3. 端点0
- 端点0,数据长度大于端点最大包大小,设置数据长度为端点最大包大小,数据长度小于端点最大包大小,设置数据长度为数据长度
4. 其他端点
- 允许多次传输,计算数据包数量,设置数据包数量,传输大小为数据长度

5. 中断中执行数据接收,或者DMA自动接收

```c
int usbd_ep_start_read(uint8_t busid, const uint8_t ep, uint8_t *data, uint32_t data_len)
{
    uint8_t ep_idx = USB_EP_GET_IDX(ep);
    uint32_t pktcnt = 0;

    if (((uint32_t)data) & 0x03) {  //确保数据地址是4字节对齐
        return -4;
    }

    if (data_len == 0) {    //数据长度为0
        USB_OTG_OUTEP(ep_idx)->DOEPTSIZ |= (USB_OTG_DOEPTSIZ_PKTCNT & (1 << 19));
        USB_OTG_OUTEP(ep_idx)->DOEPTSIZ |= (USB_OTG_DOEPTSIZ_XFRSIZ & g_dwc2_udc.out_ep[ep_idx].ep_mps);
        USB_OTG_OUTEP(ep_idx)->DOEPCTL |= (USB_OTG_DOEPCTL_CNAK | USB_OTG_DOEPCTL_EPENA);
        return 0;
    }

    if (ep_idx == 0) {  //端点0
        if (data_len > g_dwc2_udc.out_ep[ep_idx].ep_mps) {  //不允许多次传输
            data_len = g_dwc2_udc.out_ep[ep_idx].ep_mps;
        }
        g_dwc2_udc.out_ep[ep_idx].xfer_len = data_len;
        USB_OTG_OUTEP(ep_idx)->DOEPTSIZ |= (USB_OTG_DOEPTSIZ_PKTCNT & (1U << 19));
        USB_OTG_OUTEP(ep_idx)->DOEPTSIZ |= (USB_OTG_DOEPTSIZ_XFRSIZ & data_len);
    } else {    //其他端点 允许多次传输
        pktcnt = (uint16_t)((data_len + g_dwc2_udc.out_ep[ep_idx].ep_mps - 1U) / g_dwc2_udc.out_ep[ep_idx].ep_mps);

        USB_OTG_OUTEP(ep_idx)->DOEPTSIZ |= (USB_OTG_DOEPTSIZ_PKTCNT & (pktcnt << 19));
        USB_OTG_OUTEP(ep_idx)->DOEPTSIZ |= (USB_OTG_DOEPTSIZ_XFRSIZ & data_len);
    }
    // 使能接收
    return 0;
}
```

### usbd_ep_set_stall

- 停止端点传输,设置端点STALL

## usbd_ep_start_write

- 同read类似

- 数据为`USB_ENDPOINT_TYPE_ISOCHRONOUS`,执行额外操作
- 数据长度为0,设置数据包数量为1,传输大小为端点最大包大小,使能端点

## dwc2_tx_fifo_empty_procecss

- 发送数据到端点FIFO

## usbd_event_ep0_in_complete_handler

- `usbd_event_ep0_setup_complete_handler`会对`ep0_data_buf`进行处理,处理完成后,执行`usbd_ep_start_write`,进而在中断中执行`usbd_event_ep0_in_complete_handler`

```c
void usbd_event_ep0_in_complete_handler(uint8_t busid, uint8_t ep, uint32_t nbytes)
{
    struct usb_setup_packet *setup = &g_usbd_core[busid].setup;

    g_usbd_core[busid].ep0_data_buf += nbytes;
    g_usbd_core[busid].ep0_data_buf_residue -= nbytes;

    USB_LOG_DBG("EP0 send %d bytes, %d remained\r\n", nbytes, g_usbd_core[busid].ep0_data_buf_residue);

    if (g_usbd_core[busid].ep0_data_buf_residue != 0) {
        /* Start sending the remain data */
        usbd_ep_start_write(busid, USB_CONTROL_IN_EP0, g_usbd_core[busid].ep0_data_buf, g_usbd_core[busid].ep0_data_buf_residue);
    } else {
        if (g_usbd_core[busid].zlp_flag == true) {
            g_usbd_core[busid].zlp_flag = false;
            /* Send zlp to host */
            USB_LOG_DBG("EP0 Send zlp\r\n");
            usbd_ep_start_write(busid, USB_CONTROL_IN_EP0, NULL, 0);
        } else {
            /* Satisfying three conditions will jump here.
                * 1. send status completely
                * 2. send zlp completely
                * 3. send last data completely.
                */
            if (setup->wLength && ((setup->bmRequestType & USB_REQUEST_DIR_MASK) == USB_REQUEST_DIR_IN)) {
                /* if all data has sent completely, start reading out status */
                usbd_ep_start_read(busid, USB_CONTROL_OUT_EP0, NULL, 0);
            }
        }
    }
}
```

## usbd_event_ep_out_complete_handler

- 同`usbd_event_ep0_in_complete_handler`流程

## usbd_set_address

```c
int usbd_set_address(uint8_t busid, const uint8_t addr)
{
    USB_OTG_DEV->DCFG &= ~(USB_OTG_DCFG_DAD);
    USB_OTG_DEV->DCFG |= ((uint32_t)addr << 4) & USB_OTG_DCFG_DAD;
    return 0;
}
```

# device

![_images/usbdev.svg](42%20USB.assets/usbdev.svg)

## core

### usbd_desc_register

- 注册描述符

```c
void usbd_desc_register(uint8_t busid, const uint8_t *desc)
{
    memset(&g_usbd_core[busid], 0, sizeof(struct usbd_core_priv));

    g_usbd_core[busid].descriptors = desc;  // 注册描述符
    g_usbd_core[busid].intf_offset = 0;     // 接口偏移

    g_usbd_core[busid].tx_msg[0].ep = 0x80; // 发送端点
    g_usbd_core[busid].tx_msg[0].cb = usbd_event_ep0_in_complete_handler;   // 发送完成回调
    g_usbd_core[busid].rx_msg[0].ep = 0x00; // 接收端点
    g_usbd_core[busid].rx_msg[0].cb = usbd_event_ep0_out_complete_handler;  // 接收完成回调
}
```

### usbd_add_interface

- 添加一个接口驱动。 添加顺序必须按照描述符顺序。
- intf 接口驱动句柄，通常从不同 class 的 xxx_init_intf 函数获取

```c
void usbd_add_interface(uint8_t busid, struct usbd_interface *intf)
{
    intf->intf_num = g_usbd_core[busid].intf_offset;    // 接口编号
    g_usbd_core[busid].intf[g_usbd_core[busid].intf_offset] = intf; // 接口句柄
    g_usbd_core[busid].intf_offset++;   // 接口偏移
}
```

### usbd_add_endpoint

- 注册端点地址和回调函数

```c
void usbd_add_endpoint(uint8_t busid, struct usbd_endpoint *ep)
{
    if (ep->ep_addr & 0x80) {   // 发送端点,根据端点地址的最高位判断
        g_usbd_core[busid].tx_msg[ep->ep_addr & 0x7f].ep = ep->ep_addr;
        g_usbd_core[busid].tx_msg[ep->ep_addr & 0x7f].cb = ep->ep_cb;
    } else {    // 接收端点,根据端点地址的最高位判断
        g_usbd_core[busid].rx_msg[ep->ep_addr & 0x7f].ep = ep->ep_addr;
        g_usbd_core[busid].rx_msg[ep->ep_addr & 0x7f].cb = ep->ep_cb;
    }
}
```

### usbd_initialize

- 用来初始化 usb device 寄存器配置、usb 时钟、中断等，需要注意，此函数必须在所有列出的 API 最后。 如果使用 os，必须放在线程中执行。
- 填入 busid 和 USB IP 的 reg base， busid 从 0 开始，不能超过 CONFIG_USBDEV_MAX_BUS

```c
int usbd_initialize(uint8_t busid, uint32_t reg_base, void (*event_handler)(uint8_t busid, uint8_t event))
{
    int ret;
    struct usbd_bus *bus;
    bus = &g_usbdev_bus[busid];
    bus->reg_base = reg_base;
    g_usbd_core[busid].event_handler = event_handler;

    ret = usb_dc_init(busid);   //初始化USB设备寄存器
    usbd_class_event_notify_handler(busid, USBD_EVENT_INIT, NULL);  //执行接口通知函数
    g_usbd_core[busid].event_handler(busid, USBD_EVENT_INIT);
    return ret;
}
```

### usbd_class_event_notify_handler

- 执行接口通知函数:`intf->notify_handler(busid, event, arg);`

### usbd_event_reset_handler

1. 设置USB设备地址为0
2. 清空配置
3. 配置IN端点
4. 配置OUT端点
5. 执行接口通知函数
6. 执行事件处理函数

```c
void usbd_event_reset_handler(uint8_t busid)
{
    usbd_set_address(busid, 0); //设置USB设备地址为0
    g_usbd_core[busid].configuration = 0;
#ifdef CONFIG_USBDEV_ADVANCE_DESC
    g_usbd_core[busid].speed = USB_SPEED_UNKNOWN;
#endif
    struct usb_endpoint_descriptor ep0;

    ep0.bLength = 7;
    ep0.bDescriptorType = USB_DESCRIPTOR_TYPE_ENDPOINT;
    ep0.wMaxPacketSize = USB_CTRL_EP_MPS;
    ep0.bmAttributes = USB_ENDPOINT_TYPE_CONTROL;
    ep0.bEndpointAddress = USB_CONTROL_IN_EP0;
    ep0.bInterval = 0;
    usbd_ep_open(busid, &ep0);  //配置IN端点

    ep0.bEndpointAddress = USB_CONTROL_OUT_EP0;
    usbd_ep_open(busid, &ep0);  //配置OUT端点

    usbd_class_event_notify_handler(busid, USBD_EVENT_RESET, NULL);
    g_usbd_core[busid].event_handler(busid, USBD_EVENT_RESET);
}
```

### usbd_setup_request_handler

- 处理setup请求

#### USB_REQUEST_STANDARD 0x00 标准请求

- `usbd_standard_request_handler`

##### USB_REQUEST_RECIPIENT_DEVICE 0x00 设备

- `usbd_std_device_req_handler`

###### USB_REQUEST_GET_STATUS 0x00 获取设备状态

```c
    /* bit 0: self-powered */
    /* bit 1: remote wakeup */
    (*data)[0] = 0x00;
    (*data)[1] = 0x00;
    *len = 2;
```

###### USB_REQUEST_CLEAR_FEATURE 0x01 清除设备特性

###### USB_REQUEST_SET_FEATURE 0x03 设置设备特性

###### USB_REQUEST_SET_ADDRESS 0x05 设置设备地址

- 调用IP层设置设备地址

```c
    usbd_set_address(busid, value);
    *len = 0;
```

###### USB_REQUEST_GET_DESCRIPTOR 0x06 获取描述符

- 执行`ret = usbd_get_descriptor(busid, value, data, len);`

- 例如接收到:`80 06 00 01 00 00 12 00`,执行`usbd_get_descriptor`函数,返回设备描述符以及长度

- 调用`usbd_desc_register`用于注册描述符

例如`usbd_desc_register(busid, cdc_descriptor);`

```c
static bool usbd_get_descriptor(uint8_t busid, uint16_t type_index, uint8_t **data, uint32_t *len)
{
    uint8_t type = 0U;
    uint8_t index = 0U;
    uint8_t *p = NULL;
    uint32_t cur_index = 0U;
    bool found = false;

    type = HI_BYTE(type_index);
    index = LO_BYTE(type_index);

    p = (uint8_t *)g_usbd_core[busid].descriptors;  //获取描述符

    cur_index = 0U;

    //查找描述符
    while (p[DESC_bLength] != 0U) {
        if (p[DESC_bDescriptorType] == type) {
            if (cur_index == index) {
                found = true;
                break;
            }

            cur_index++;
        }

        /* skip to next descriptor */
        p += p[DESC_bLength];
    }
    //返回描述符及长度
    if (found) {
        if ((type == USB_DESCRIPTOR_TYPE_CONFIGURATION) || ((type == USB_DESCRIPTOR_TYPE_OTHER_SPEED))) {
            /* configuration or other speed descriptor is an
             * exception, length is at offset 2 and 3
             */
            *len = (p[CONF_DESC_wTotalLength]) |
                   (p[CONF_DESC_wTotalLength + 1] << 8);
        } else {
            /* normally length is at offset 0 */
            *len = p[DESC_bLength];
        }
        *data = p;
        //memcpy(*data, p, *len);
    } else {
        /* nothing found */
        USB_LOG_ERR("descriptor <type:0x%02x,index:0x%02x> not found!\r\n", type, index);
    }

    return found;
}
```

###### USB_REQUEST_SET_DESCRIPTOR 0x07 设置描述符

###### USB_REQUEST_GET_CONFIGURATION 0x08 获取配置

###### USB_REQUEST_SET_CONFIGURATION 0x09 设置配置

- `wValue`字段的下一个字节指定所需的配置。此配置值必须为零或与配置描述符中的配置值匹配。如果配置值为零，则设备处于地址状态。保留wValue字段的上一个字节。

- `usbd_set_configuration`执行流程
    1. 遍历全局描述符,找到配置描述符,标记为`found`
    2. 找到接口描述符,记录`cur_alt_setting`
    3. 找打端点描述符,匹配配置和接口,执行`usbd_set_endpoint`

```c
    value &= 0xFF;

    if (!usbd_set_configuration(busid, value, 0)) {
        ret = false;
    } else {
        g_usbd_core[busid].configuration = value;
        usbd_class_event_notify_handler(busid, USBD_EVENT_CONFIGURED, NULL);    //执行接口通知函数
        g_usbd_core[busid].event_handler(busid, USBD_EVENT_CONFIGURED);   //执行事件处理函数
    }
    *len = 0;
```


```c
static bool usbd_set_configuration(uint8_t busid, uint8_t config_index, uint8_t alt_setting)
{
    uint8_t cur_alt_setting = 0xFF;
    uint8_t cur_config = 0xFF;
    bool found = false;
    const uint8_t *p;
    uint32_t desc_len = 0;
    uint32_t current_desc_len = 0;

    p = (uint8_t *)g_usbd_core[busid].descriptors;

    /* configure endpoints for this configuration/altsetting */
    while (p[DESC_bLength] != 0U) {
        switch (p[DESC_bDescriptorType]) {
            case USB_DESCRIPTOR_TYPE_CONFIGURATION:
                /* remember current configuration index */
                cur_config = p[CONF_DESC_bConfigurationValue];

                if (cur_config == config_index) {
                    found = true;

                    current_desc_len = 0;
                    desc_len = (p[CONF_DESC_wTotalLength]) |
                               (p[CONF_DESC_wTotalLength + 1] << 8);
                }

                break;

            case USB_DESCRIPTOR_TYPE_INTERFACE:
                /* remember current alternate setting */
                cur_alt_setting =
                    p[INTF_DESC_bAlternateSetting];
                break;

            case USB_DESCRIPTOR_TYPE_ENDPOINT:
                if ((cur_config != config_index) ||
                    (cur_alt_setting != alt_setting)) {
                    break;
                }

                found = usbd_set_endpoint(busid, (struct usb_endpoint_descriptor *)p);
                break;

            default:
                break;
        }

        /* skip to next descriptor */
        p += p[DESC_bLength];
        current_desc_len += p[DESC_bLength];
        if (current_desc_len >= desc_len && desc_len) {
            break;
        }
    }

    return found;
}
```



###### USB_REQUEST_GET_INTERFACE 0x0A 获取接口
###### USB_REQUEST_SET_INTERFACE 0x0B 设置接口
- 返回false

##### USB_REQUEST_RECIPIENT_INTERFACE 0x01 接口

##### USB_REQUEST_RECIPIENT_ENDPOINT  0x02 端点

#### USB_REQUEST_CLASS 0x1 类

```c
    if (usbd_class_request_handler(busid, setup, data, len) < 0) {
        USB_LOG_ERR("class request error\r\n");
        usbd_print_setup(setup);
        return false;
    }
```

##### USB_REQUEST_RECIPIENT_INTERFACE 0x01 接口

- 匹配对应的接口函数进行执行

```c
    for (uint8_t i = 0; i < g_usbd_core[busid].intf_offset; i++) {
        struct usbd_interface *intf = g_usbd_core[busid].intf[i];

        if (intf && intf->class_interface_handler && (intf->intf_num == (setup->wIndex & 0xFF))) {
            return intf->class_interface_handler(busid, setup, data, len);
        }
    }
```

##### USB_REQUEST_RECIPIENT_ENDPOINT 0x02 端点

#### USB_REQUEST_VENDOR 0x2 厂商

### usbd_set_endpoint

```c
static bool usbd_set_endpoint(uint8_t busid, const struct usb_endpoint_descriptor *ep)
{
    USB_LOG_DBG("Open ep:0x%02x type:%u mps:%u\r\n",
                 ep->bEndpointAddress,
                 USB_GET_ENDPOINT_TYPE(ep->bmAttributes),
                 USB_GET_MAXPACKETSIZE(ep->wMaxPacketSize));

    if (ep->bEndpointAddress & 0x80) {
        g_usbd_core[busid].tx_msg[ep->bEndpointAddress & 0x7f].ep_mps = USB_GET_MAXPACKETSIZE(ep->wMaxPacketSize);  //设置发送端点最大包大小
        g_usbd_core[busid].tx_msg[ep->bEndpointAddress & 0x7f].ep_mult = USB_GET_MULT(ep->wMaxPacketSize);          //设置发送端点多包
    } else {
        g_usbd_core[busid].rx_msg[ep->bEndpointAddress & 0x7f].ep_mps = USB_GET_MAXPACKETSIZE(ep->wMaxPacketSize);  //设置接收端点最大包大小
        g_usbd_core[busid].rx_msg[ep->bEndpointAddress & 0x7f].ep_mult = USB_GET_MULT(ep->wMaxPacketSize);          //设置接收端点多包
    }

    return usbd_ep_open(busid, ep) == 0 ? true : false;
}
```


## CDC (Communication Device Class)

### cdc function

#### usbd_cdc_acm_init_intf

- 用来初始化 USB CDC ACM 类接口，并实现该接口相关的函数
```c
struct usbd_interface *usbd_cdc_acm_init_intf(uint8_t busid, struct usbd_interface *intf)
{
    intf->class_interface_handler = cdc_acm_class_interface_request_handler;    //用来处理 USB CDC ACM 类 Setup 请求
    intf->class_endpoint_handler = NULL;    // 用来处理 USB CDC ACM 类端点请求
    intf->vendor_handler = NULL;    // 用来处理 USB CDC ACM 厂商特定的 Setup 请求
    intf->notify_handler = NULL;    // 用来处理 USB CDC 其他中断回调函数

    return intf;
}
```

### CDC-ACM (Abstract Control Model)

- CDC-ACM用于实现虚拟串口,无需安装驱动,系统会自动识别为串口设备;但是CDC-ACM的速度较慢,不适合高速传输,且不支持流控制;即与硬件串口无关
- CDC-ACM的虚拟串口,如果是充当Bridge的角色，即上位机发送的数据是需要CDC设备继续下传到第三方设备，此时波特率有意义， 上位机和你的第三方设备的串口波特率必须设置为相同才能正常数据传输
- USB CDC虚拟串口实质是USB通信，在电脑端映射成串口，波特率没有实际意义。
- 另外的实现虚拟串口的方式是VCP(Virtual COM Port),需要安装驱动,但是速度较快,支持流控制;

![1723797941724](image/42USB/1723797941724.png)

21. 主机发送`GET LINE CODING Request` 获取波特率,停止位,校验位等信息
22. 设备返回波特率,停止位,校验位等信息
23. 主机发送`SET CONTROL LINE STATE Request` 设置DTR和RTS
24. 设备返回ACK
25. 主机发送`SET LINE CODING Request` 设置波特率,停止位,校验位等信息
26. 设备返回ACK
27. 主机发送`GET LINE CODING Request` 获取波特率,停止位,校验位等信息
28. 设备返回波特率,停止位,校验位等信息
29. URB_BULK in -> 45 回应主机请求
30. URB_INTERRUPT in -> 64 回应主机请求
35. 主机发送`SET LINE CODING Request` 设置波特率115200


#### 初始化

1. `cdc_acm_init`

There are three classes that make up the definition for communications devices: 
- Communications Device Class
- Communications Interface Class
- Data Interface Class. 

```c
/*!< endpoint address */
#define CDC_IN_EP  0x81
#define CDC_OUT_EP 0x02

/*!< endpoint call back */
struct usbd_endpoint cdc_out_ep = {
    .ep_addr = CDC_OUT_EP,
    .ep_cb = usbd_cdc_acm_bulk_out
};

struct usbd_endpoint cdc_in_ep = {
    .ep_addr = CDC_IN_EP,
    .ep_cb = usbd_cdc_acm_bulk_in
};

void cdc_acm_init(uint8_t busid, uint32_t reg_base)
{
    usbd_desc_register(busid, cdc_descriptor);  // 注册描述符
    //因为 cdc 有 2 个接口，所以我们需要调用 usbd_add_interface 2 次
    usbd_add_interface(busid, usbd_cdc_acm_init_intf(busid, &intf0));   // 初始化intf0为CDC ACM接口,并添加到接口列表
    usbd_add_interface(busid, usbd_cdc_acm_init_intf(busid, &intf1));   // 初始化intf1为CDC ACM接口,并添加到接口列表
    usbd_add_endpoint(busid, &cdc_out_ep);  // 添加接收端点
    usbd_add_endpoint(busid, &cdc_in_ep);   // 添加发送端点
    usbd_initialize(busid, reg_base, usbd_event_handler);   // 初始化USB设备,并注册事件处理函数,执行接口通知函数`USBD_EVENT_INIT`
}
```

#### 全局描述符

1. 设备描述符:USB2.0,基类为多功能设备类,IAD.(接口关联描述符)
2. 配置描述符:接口数为2,配置值为1,属性为总线供电,最大功率为100mA
3. CDC ACM 描述符:接口数为2,类为CDC,子类为ACM,协议为V.25ter,最大包大小为64
4. 第一个字符串描述符为厂商描述符, 第二个字符串描述符为产品描述符, 第三个字符串描述符为序列号描述符

```c
/*!< global descriptor */
static const uint8_t cdc_descriptor[] = {
    USB_DEVICE_DESCRIPTOR_INIT(USB_2_0, 0xEF, 0x02, 0x01, USBD_VID, USBD_PID, 0x0100, 0x01),
    USB_CONFIG_DESCRIPTOR_INIT(USB_CONFIG_SIZE, 0x02, 0x01, USB_CONFIG_BUS_POWERED, USBD_MAX_POWER),
    CDC_ACM_DESCRIPTOR_INIT(0x00, CDC_INT_EP, CDC_OUT_EP, CDC_IN_EP, CDC_MAX_MPS, 0x02),
    ///////////////////////////////////////
    /// string0 descriptor
    ///////////////////////////////////////
    USB_LANGID_INIT(USBD_LANGID_STRING),
    ///////////////////////////////////////
    /// string1 descriptor
    ///////////////////////////////////////
    0x14,                       /* bLength */
    USB_DESCRIPTOR_TYPE_STRING, /* bDescriptorType */
    'C', 0x00,                  /* wcChar0 */
    'h', 0x00,                  /* wcChar1 */
    'e', 0x00,                  /* wcChar2 */
    'r', 0x00,                  /* wcChar3 */
    'r', 0x00,                  /* wcChar4 */
    'y', 0x00,                  /* wcChar5 */
    'U', 0x00,                  /* wcChar6 */
    'S', 0x00,                  /* wcChar7 */
    'B', 0x00,                  /* wcChar8 */
    ///////////////////////////////////////
    /// string2 descriptor
    ///////////////////////////////////////
    0x26,                       /* bLength */
    USB_DESCRIPTOR_TYPE_STRING, /* bDescriptorType */
    'C', 0x00,                  /* wcChar0 */
    'h', 0x00,                  /* wcChar1 */
    'e', 0x00,                  /* wcChar2 */
    'r', 0x00,                  /* wcChar3 */
    'r', 0x00,                  /* wcChar4 */
    'y', 0x00,                  /* wcChar5 */
    'U', 0x00,                  /* wcChar6 */
    'S', 0x00,                  /* wcChar7 */
    'B', 0x00,                  /* wcChar8 */
    ' ', 0x00,                  /* wcChar9 */
    'C', 0x00,                  /* wcChar10 */
    'D', 0x00,                  /* wcChar11 */
    'C', 0x00,                  /* wcChar12 */
    ' ', 0x00,                  /* wcChar13 */
    'D', 0x00,                  /* wcChar14 */
    'E', 0x00,                  /* wcChar15 */
    'M', 0x00,                  /* wcChar16 */
    'O', 0x00,                  /* wcChar17 */
    ///////////////////////////////////////
    /// string3 descriptor
    ///////////////////////////////////////
    0x16,                       /* bLength */
    USB_DESCRIPTOR_TYPE_STRING, /* bDescriptorType */
    '2', 0x00,                  /* wcChar0 */
    '0', 0x00,                  /* wcChar1 */
    '2', 0x00,                  /* wcChar2 */
    '2', 0x00,                  /* wcChar3 */
    '1', 0x00,                  /* wcChar4 */
    '2', 0x00,                  /* wcChar5 */
    '3', 0x00,                  /* wcChar6 */
    '4', 0x00,                  /* wcChar7 */
    '5', 0x00,                  /* wcChar8 */
    '6', 0x00,                  /* wcChar9 */
#ifdef CONFIG_USB_HS
    ///////////////////////////////////////
    /// device qualifier descriptor
    ///////////////////////////////////////
    0x0a,
    USB_DESCRIPTOR_TYPE_DEVICE_QUALIFIER,
    0x00,
    0x02,
    0x02,
    0x02,
    0x01,
    0x40,
    0x01,
    0x00,
#endif
    0x00
};
```

#### CDC_ACM 描述符

##### 描述符举例

1. IAD描述符
- bFunctionClass: `Communications Device Class`;参考<<CDC120-20101103-track.pdf>> 4.1
- bFunctionSubClass: `Abstract Control Model` 0X02;参考<<CDC120-20101103-track.pdf>> 4.3
- bFunctionProtocol: `AT Commands: V.250 etc` 0X01;参考<<CDC120-20101103-track.pdf>> 4.4
- iFunction: 0x00; 可选的函数名字符串描述符索引。

2. 接口描述符
- bInterfaceNumber: CDC ACM接口编号 0x00
- bAlternateSetting: 0x00; 可选的备用设置号
- bNumEndpoints: 0x01; 端点数量
- bInterfaceClass: CDC类 0x02
- bInterfaceSubClass: ACM接口子类 0x02
- bInterfaceProtocol: AT Commands: V.250 etc协议 0x01
- iInterface: 接口字符串描述符索引

3. CDC功能描述符
- bcdCDC: CDC规范版本号

4. Call Management功能描述符
- bmCapabilities:设备仅通过通信类接口发送,设备本身不处理呼叫管理
- bDataInterface: (bFirstInterface + 1)  可选用于呼叫管理的数据类接口的接口号。

5. 抽象控制管理功能描述符
- bmCapabilities: 0x02 
  - 通信组合功能        不支持
  - 链路请求和状态通知   支持
  - Send_Break         不支持
  - 网络链接            不支持

6. Union功能描述符
- bMasterInterface: 通信或数据类接口的接口号，指定为联合的控制接口;
- bSlaveInterface0: 联合中第一个从属接口的接口号
- 这里来说,`CALL_MANAGEMENT`为从属接口

7. 端点描述符
- bEndpointAddress: 端点地址 0x81 (IN端点)
- bmAttributes: 0x03 (中断传输)
- wMaxPacketSize: 0x08 0x00 (8 bytes)
- bInterval: 0x0a (10ms)

8. 接口描述符
- bInterfaceNumber: CDC ACM接口编号 0x01
- bAlternateSetting: 0x00; 可选的备用设置号
- bNumEndpoints: 0x02; 端点数量
- bInterfaceClass: 数据接口类代码 0X0A
- bInterfaceSubClass: 0x00 无 该字段未用于Data Class接口，其值应为00h
- bInterfaceProtocol: 0x00 无 不需要特定于类的协议
- iInterface: ACM接口字符串描述符索引

9. 端点描述符
- bEndpointAddress: 端点地址 0x02 (OUT端点)
- bmAttributes: 0x02 (块传输)
- wMaxPacketSize: 0x40 0x00 (64 bytes)
- bInterval: 0x00 (不使用)

10. 端点描述符
- bEndpointAddress: 端点地址 0x82 (IN端点)
- bmAttributes: 0x02 (块传输)
- wMaxPacketSize: 0x40 0x00 (64 bytes)
- bInterval: 0x00 (不使用)

11. 字符串描述符
- 语言ID描述符
- 字符串描述符1
- 字符串描述符2
- 字符串描述符3

```c
/*
    *@bFirstInterface: CDC ACM接口编号
    *@int_ep: CDC ACM接口中断端点
    *@out_ep: CDC ACM接口接收端点
    *@in_ep: CDC ACM接口发送端点
    *@wMaxPacketSize: CDC ACM接口最大包大小
    *@str_idx: CDC ACM接口字符串描述符索引
*/
#define CDC_ACM_DESCRIPTOR_INIT(bFirstInterface, int_ep, out_ep, in_ep, wMaxPacketSize, str_idx) \
    /* Interface Associate */                                                                  \
    0x08,                                                  /* bLength */                       \
    USB_DESCRIPTOR_TYPE_INTERFACE_ASSOCIATION,             /* bDescriptorType */               \
    bFirstInterface,                                       /* bFirstInterface */               \
    0x02,                                                  /* bInterfaceCount */               \
    USB_DEVICE_CLASS_CDC,                                  /* bFunctionClass */                \
    CDC_ABSTRACT_CONTROL_MODEL,                            /* bFunctionSubClass */             \
    CDC_COMMON_PROTOCOL_AT_COMMANDS,                       /* bFunctionProtocol */             \
    0x00,                                                  /* iFunction */                     \
    0x09,                                                  /* bLength */                       \
    USB_DESCRIPTOR_TYPE_INTERFACE,                         /* bDescriptorType */               \
    bFirstInterface,                                       /* bInterfaceNumber */              \
    0x00,                                                  /* bAlternateSetting */             \
    0x01,                                                  /* bNumEndpoints */                 \
    USB_DEVICE_CLASS_CDC,                                  /* bInterfaceClass */               \
    CDC_ABSTRACT_CONTROL_MODEL,                            /* bInterfaceSubClass */            \
    CDC_COMMON_PROTOCOL_AT_COMMANDS,                       /* bInterfaceProtocol */            \
    str_idx,                                               /* iInterface */                    \
    0x05,                                                  /* bLength */                       \
    CDC_CS_INTERFACE,                                      /* bDescriptorType */               \
    CDC_FUNC_DESC_HEADER,                                  /* bDescriptorSubtype */            \
    WBVAL(CDC_V1_10),                                      /* bcdCDC */                        \
    0x05,                                                  /* bLength */                       \
    CDC_CS_INTERFACE,                                      /* bDescriptorType */               \
    CDC_FUNC_DESC_CALL_MANAGEMENT,                         /* bDescriptorSubtype */            \
    0x00,                                                  /* bmCapabilities */                \
    (uint8_t)(bFirstInterface + 1),                        /* bDataInterface */                \
    0x04,                                                  /* bLength */                       \
    CDC_CS_INTERFACE,                                      /* bDescriptorType */               \
    CDC_FUNC_DESC_ABSTRACT_CONTROL_MANAGEMENT,             /* bDescriptorSubtype */            \
    0x02,                                                  /* bmCapabilities */                \
    0x05,                                                  /* bLength */                       \
    CDC_CS_INTERFACE,                                      /* bDescriptorType */               \
    CDC_FUNC_DESC_UNION,                                   /* bDescriptorSubtype */            \
    bFirstInterface,                                       /* bMasterInterface */              \
    (uint8_t)(bFirstInterface + 1),                        /* bSlaveInterface0 */              \
    0x07,                                                  /* bLength */                       \
    USB_DESCRIPTOR_TYPE_ENDPOINT,                          /* bDescriptorType */               \
    int_ep,                                                /* bEndpointAddress */              \
    0x03,                                                  /* bmAttributes */                  \
    0x08, 0x00,                                            /* wMaxPacketSize */                \
    0x0a,                                                  /* bInterval */                     \
    0x09,                                                  /* bLength */                       \
    USB_DESCRIPTOR_TYPE_INTERFACE,                         /* bDescriptorType */               \
    (uint8_t)(bFirstInterface + 1),                        /* bInterfaceNumber */              \
    0x00,                                                  /* bAlternateSetting */             \
    0x02,                                                  /* bNumEndpoints */                 \
    CDC_DATA_INTERFACE_CLASS,                              /* bInterfaceClass */               \
    0x00,                                                  /* bInterfaceSubClass */            \
    0x00,                                                  /* bInterfaceProtocol */            \
    0x00,                                                  /* iInterface */                    \
    0x07,                                                  /* bLength */                       \
    USB_DESCRIPTOR_TYPE_ENDPOINT,                          /* bDescriptorType */               \
    out_ep,                                                /* bEndpointAddress */              \
    0x02,                                                  /* bmAttributes */                  \
    WBVAL(wMaxPacketSize),                                 /* wMaxPacketSize */                \
    0x00,                                                  /* bInterval */                     \
    0x07,                                                  /* bLength */                       \
    USB_DESCRIPTOR_TYPE_ENDPOINT,                          /* bDescriptorType */               \
    in_ep,                                                 /* bEndpointAddress */              \
    0x02,                                                  /* bmAttributes */                  \
    WBVAL(wMaxPacketSize),                                 /* wMaxPacketSize */                \
    0x00                                                   /* bInterval */
```

#### usbd_event_handler

- `USB_REQUEST_SET_CONFIGURATION`执行后,执行`g_usbd_core[busid].event_handler(busid, USBD_EVENT_CONFIGURED);`

```c
static void usbd_event_handler(uint8_t busid, uint8_t event)
{
    switch (event) {
        case USBD_EVENT_RESET:
            break;
        case USBD_EVENT_CONNECTED:
            break;
        case USBD_EVENT_DISCONNECTED:
            break;
        case USBD_EVENT_RESUME:
            break;
        case USBD_EVENT_SUSPEND:
            break;
        case USBD_EVENT_CONFIGURED:
            ep_tx_busy_flag = false;
            /* setup first out ep read transfer */
            usbd_ep_start_read(busid, CDC_OUT_EP, read_buffer, 2048);
            break;
        case USBD_EVENT_SET_REMOTE_WAKEUP:
            break;
        case USBD_EVENT_CLR_REMOTE_WAKEUP:
            break;

        default:
            break;
    }
}
```

#### cdc_acm_class_interface_request_handler

- 主机发送`GET LINE CODING Request`,即CLASS INTERFACE REQUEST,执行
- 进而执行此函数

##### CDC_REQUEST_GET_LINE_CODING 0x21 获取线编码

```c
__WEAK void usbd_cdc_acm_get_line_coding(uint8_t busid, uint8_t intf, struct cdc_line_coding *line_coding)
{
    line_coding->dwDTERate = 2000000;   //波特率
    line_coding->bDataBits = 8;         //数据位
    line_coding->bParityType = 0;       //校验位
    line_coding->bCharFormat = 0;       //停止位
}
```

##### CDC_REQUEST_SET_CONTROL_LINE_STATE 0x22 设置控制线状态

- dtr: 数据终端准备好 
- rts: 请求发送

```c
    dtr = (setup->wValue & 0x0001);
    rts = (setup->wValue & 0x0002);
    USB_LOG_DBG("Set intf:%d DTR 0x%x,RTS 0x%x\r\n",
                intf_num,
                dtr,
                rts);
    usbd_cdc_acm_set_dtr(busid, intf_num, dtr);
    usbd_cdc_acm_set_rts(busid, intf_num, rts);
```

- 例如,通过`usbd_cdc_acm_set_dtr`来实现串口打开才输出数据功能

```c
void usbd_cdc_acm_set_dtr(uint8_t busid, uint8_t intf, bool dtr)
{
    if (dtr) {
        dtr_enable = 1;
    } else {
        dtr_enable = 0;
    }
}

void cdc_acm_data_send_with_dtr_test(uint8_t busid)
{
    if (dtr_enable) {
        ep_tx_busy_flag = true;
        usbd_ep_start_write(busid, CDC_IN_EP, write_buffer, 2048);
        while (ep_tx_busy_flag) {
        }
    }
}
```

##### CDC_REQUEST_SET_LINE_CODING 0x20 设置线编码

- 同上

```c
    memcpy(&line_coding, *data, setup->wLength);
    USB_LOG_DBG("Set intf:%d linecoding <%d %d %s %s>\r\n",
                intf_num,
                line_coding.dwDTERate,
                line_coding.bDataBits,
                parity_name[line_coding.bParityType],
                stop_name[line_coding.bCharFormat]);

    usbd_cdc_acm_set_line_coding(busid, intf_num, &line_coding);
```

### Endpoint描述符

#### Functional Descriptors
- 参考<<CDC120-20101103-track.pdf>> 5.2.3 Table 11: Functional Descriptor General Format

##### Header Functional Descriptor
- 类特定的描述符应该从表11中定义的头开始。bcdCDC字段标识通信设备规范的USB类定义(本规范)的发布，该接口及其描述符符合该规范。

##### Union Functional Descriptor
- 联合功能描述符描述了一组接口之间的关系，这些接口可以被认为是一个功能单元。它只能发生在类特定部分描述符。
- 组中的一个接口被指定为组的主接口或控制接口，并且某些特定于类的消息可以发送到该接口以对整个组起作用。类似地，整个组的通知可以从该接口发送，但适用于整个组的接口。该组中的接口可以包括通信、数据或任何其他有效的USB接口类(包括但不限于音频、HID和监视器)。

## MSC (Mass Storage Class)

### 抓包

#### 枚举过程

1. 忽略设备描述符及字符串描述符请求和回应过程
2. 主机发送`GET CONFIGURATION Request` 获取配置描述符
    - 配置端点
    - 执行`usbd_class_event_notify_handler(busid, USBD_EVENT_CONFIGURED, NULL);`,执行`msc_storage_notify_handler`
    - 开始读取CBW,MSC Bulk-Only Command Block Wrapper (CBW),存储至`g_usbd_msc[busid].cbw`
    - `stage`状态 = MSC_READ_CBW;
```log
[15:58:27] [412][I/USB] Setup: bmRequestType 0x00, bRequest 0x09, wValue 0x0001, wIndex 0x0000, wLength 0x0000
[15:58:27] [412][D/USB] Open ep:0x02 type:2 mps:64
[15:58:27] [412][D/USB] Open ep:0x81 type:2 mps:64
[15:58:27] [412][D/USB] Start reading cbw
```

3. 请求类型: Class Interface Request, 方向主机到设备, 请求:Get Max LUN (GML)
    - 回复`0`lun

```log
[a1 fe 00 00 00 00 01 00]
[15:58:27] [431]USB confi[I/USB] Setup: bmRequestType 0xa1, bRequest 0xfe, wValue 0x0000, wIndex 0x0000, wLength 0x0001
[15:58:27] [431][D/USB] MSC Class request: bRequest 0xfe
[00]
[15:58:27] [431][D/USB] EP0 send 1 bytes, 0 remained
[15:58:27] [447][D/USB] EP0 recv out status
```

4. 主机通过端点2发送CBW, SCSI: Inquiry LUN: 0x00 
    - Signature: 0x43425355 签名
    - Tag: 0x16db9010
    - Data Transfer Length: 36
    - flag: 0x80
        - target: 0x00
        - lun: 0x00
        - CDB Length: 6
    - CDB: 0x12

```log
[55 53 42 43 10 90 db 16 24 00 00 00 80 00 06 12 00 00 24 00 00 00 00 00 00 00 00 00 00 00]
[2024/8/17 15:58:27] [448][D/USB] Decode CB:0x12
```

5. 解码SCSI命令,执行`SCSI_inquiry`,回复设备信息
    - 外设限定符: 0x00 , 设备类型连接到逻辑单元
    - 设备类型: 0x00 , 直接访问设备(磁盘)
    - RMB: 0x01 , 可移动介质
    - Device-type modifier: 0x00 不支持
    - ISO/IEC 646: 0x02 , ASCII
    - Response data format: 0x01 , ACSI-2
    - Additional Length: 0x1f , 31 bytes
    - Vendor ID: "        "
    - Product ID: "        "
    - Product Revision: "0.01"
    - 回复长度: 36

```log
[00 80 02 02 1f 00 00 00 20 20 20 20 20 20 20 20 0 20 20 20 20 20 20 20 20 20 20 20 20 20 20 20 20 30 2e 30 31]
[2024/8/17 15:58:27] [448][D/USB] Send info len:36
```

6. 设备通过端点1发送CSW状态(good),转入`MSC_READ_CBW`状态
    - Signature: 0x53425355
    - Tag: 0x16db9010
    - dDataResidue: 0, 预期与实际数据长度差异
    - Status: 0x00 (Passed[good])

```log
[55 53 42 53 10 90 db 16 00 00 00 00 00]
[15:58:27] [448] [D/USB] Send csw
[15:58:27] [448]S[D/USB] Start reading cbw
```

7. 主机通过端点2发送CBW, SCSI Command: 0x23(READ FORMAT CAPACITIES) LUN:0x00 
    - Signature: 0x43425355 签名
    - Tag: 0x0d89a010
    - Data Transfer Length: 252
    - flag: 0x80
        - target: 0x00
        - lun: 0x00
        - CDB Length: 10
    - CDB: 0x23 READ FORMAT CAPACITIES
        - LUN: 0x00
        - Allocation Length: 0xfc = 252

    - 设备回复容量信息(512字节块,1000块)= 512KB
        - Capacity List Length: 8
        - Number of blocks: 0x000003e8 = 1000
        - Desc Type: 0x02 = 可格式化设备
        - Block Length: 0x200 = 512

    SW状态(GOOD),转入`MSC_READ_CBW`状态

```log
[55 53 42 43 10 a0 89 0d fc 00 00 00 80 00 0a 23 00 00 00 00 00 00 00 fc 00 00 00 00 00 00 00]
[15:58:27] [466][D/USB] Decode CB:0x23

[00 00 00 08 00 00 03 e8 02 00 02 00]
[15:58:27] [466][D/USB] Send info len:12

[55 53 42 53 10 a0 89 0d f0 00 00 00 00]
[15:58:27] [466][D/USB] Send csw

[15:58:27] [466][D/USB] Start reading cbw
```

8. 主机通过端点2发送CBW, SCSI Command: 0x25(READ CAPACITY) LUN:0x00 
    - Signature: 0x43425355 签名
    - Tag: 0x17db9010
    - Data Transfer Length: 8
    - flag: 0x80
        - target: 0x00
        - lun: 0x00
        - CDB Length: 10
    - CDB: 0x25 READ CAPACITY
        - LUN: 0x00
        - RelAdr: 0x00
        - Logical Block Address: 0x00000000
        - PMI: 0x00

    - 设备回复容量信息(512字节块,1000块)= 512KB
        - Last Logical Block Address: 0x000003e7 = 999
        - Block Length: 0x200 = 512

```log
[55 53 42 43 10 d0 0e 17 08 00 00 00 80 00 0a 25 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[15:58:27] [502][D/USB] Decode CB:0x25

[00 00 03 e7 00 00 02 00]
[15:58:27] [502][D/USB] Send info len:8

[15:58:27] [550][D/USB] Send csw
[15:58:27] [662][D/USB] Start reading cbw
```

9. 主机通过端点2发送CBW, SCSI Command: 0x1A(MODE SENSE(6)) LUN:0x00
    - Signature: 0x43425355 签名
    - Tag: 0x16db9010
    - Data Transfer Length: 192
    - flag: 0x80
        - target: 0x00
        - lun: 0x00
        - CDB Length: 6
    - CDB: 0x1A MODE SENSE(6)
        - LUN: 0x00
        - DBD: 0x00
        - ALLOCATE LENGTH: 192
        - Control: 0x00
    - 回复设备信息
        - Mode Data Length: 0x00
        - Medium Type: 0x00
        - Device-Specific Parameter: 0x00
        - Block Descriptor Length: 0x00

```log
[55 53 42 43 10 40 ff 16 c0 00 00 00 80 00 06 1a 00 1c 00 c0 00 00 00 00 00 00 00 00 00 00 00]
[15:58:27] [662][D/USB] Decode CB:0x1a

[03 00 00 00]
[15:58:27] [662][D/USB] Send info len:4
[15:58:27] [662][D/USB] Send csw
[15:58:27] [662][D/USB] Start reading cbw
```

10. 主机通过端点2发送CBW, SCSI Command: 0X28(READ(10)) LUN:0x00
    - Signature: 0x43425355 签名
    - Tag: 0X1405b290
    - Data Transfer Length: 512
    - flag: 0x80
        - target: 0x00
        - lun: 0x00
        - CDB Length: 10
    - CDB: 0x28 READ(10)
        - LUN: 0x00
        - rdprotect: 0x00
        - dpo: 0x00
        - fua: 0x00
        - rarc: 0x00
        - Logical Block Address: 0x00000000
        - Group Number: 0x00
        - Transfer Length: 1
        - Control: 0x00

    - 回复返回所需LBA地址数据

```log
[55 53 42 43 90 b2 05 14 00 02 00 00 80 00 0a 28 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00]
[15:58:27] [687][D/USB] Decode CB:0x28
[15:58:27] [687][D/USB] lba: 0x0000 //读取的逻辑块地址
[15:58:27] [687][D/USB] nsectors: 0x01 //读取的扇区数
[15:58:27] [687][D/USB] read lba:0

[0000   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0010   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0020   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0030   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0040   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0050   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0060   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0070   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0080   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0090   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[00a0   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[00b0   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[00c0   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[00d0   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[00e0   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[00f0   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0100   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0110   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0120   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0130   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0140   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0150   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0160   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0170   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0180   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[0190   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[01a0   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[01b0   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[01c0   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[01d0   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[01e0   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[01f0   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]

[15:58:27] [687][D/USB] Send csw
[15:58:27] [687][D/USB] Start reading cbw
```

11. 读取lba:2的数据,读取0~15块数据
- 应该是获取MBR分区信息和FAT表信息

```log
144 [2024/8/17 15:58:27] [746][D/USB] Decode CB:0x28
145 [2024/8/17 15:58:27] [746][D/USB] lba: 0x0002
146 [2024/8/17 15:58:27] [746][D/USB] nsectors: 0x01
147 [2024/8/17 15:58:27] [757][D/USB] read lba:2

209 [2024/8/17 15:58:27] [915][D/USB] Decode CB:0x28
210 [2024/8/17 15:58:27] [915][D/USB] lba: 0x0000
211 [2024/8/17 15:58:27] [928][D/USB] nsectors: 0x10
212 [2024/8/17 15:58:27] [928][D/USB] read lba:0
213 [2024/8/17 15:58:27] [928][D/USB] read lba:1
214 [2024/8/17 15:58:27] [928][D/USB] read lba:2
215 [2024/8/17 15:58:27] [928][D/USB] read lba:3
216 [2024/8/17 15:58:27] [939][D/USB] read lba:4
217 [2024/8/17 15:58:27] [939][D/USB] read lba:5
218 [2024/8/17 15:58:27] [939][D/USB] read lba:6
219 [2024/8/17 15:58:27] [939][D/USB] read lba:7
220 [2024/8/17 15:58:27] [953][D/USB] read lba:8
221 [2024/8/17 15:58:27] [953][D/USB] read lba:9
222 [2024/8/17 15:58:27] [953][D/USB] read lba:10
223 [2024/8/17 15:58:27] [953][D/USB] read lba:11
224 [2024/8/17 15:58:27] [953][D/USB] read lba:12
225 [2024/8/17 15:58:27] [965][D/USB] read lba:13
226 [2024/8/17 15:58:27] [965][D/USB] read lba:14
227 [2024/8/17 15:58:27] [965][D/USB] read lba:15
```

12. 主机通过端点2发送CBW, SCSI Command: 0x00(TEST UNIT READY) LUN:0x00
    - 回复(Test Unit Ready) (Good)

```log
[55 53 42 43 10 30 50 1d 00 00 00 00 00 00 06 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
[2024/8/18 15:24:43] [240][I/USB] Decode CB:0x00
[55 53 42 53 10 30 50 1d 00 00 00 00 00]
```

13. 发送CBW, SCSI Command: 0x1e(PREVENT-ALLOW MEDIUM REMOVAL) LUN:0x00
    - Prevent Allow Flags: 0x00 不允许移除
    - 回复(Prevent/Allow Medium Removal) (Good)
    发送CBW, SCSI Command: 0x1e(PREVENT-ALLOW MEDIUM REMOVAL) LUN:0x00
    - Prevent Allow Flags: 0x01 允许移除
    - 回复(Prevent/Allow Medium Removal) (Good)

```log
[55 53 42 43 60 95 ca 16 00 00 00 00 00 00 06 1e 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00]
 211 [2024/8/18 15:24:43] [645][I/USB] Decode CB:0x1e
 212 [2024/8/18 15:24:43] [645][I/USB] Decode CB:0x1e
[55 53 42 43 60 95 ca 16 00 00 00 00 00 00 06 1e 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00]
```

#### 数据交互过程

##### 不断读取LBA分区数据(wireshark抓包导致)

-  event:2 MSC_DATA_IN事件
- ?可能是未格式化缘故

```log
1647 [2024/8/18 15:17:42] [766][I/USB] read lba:64
1648 [2024/8/18 15:17:42] [766][I/USB] event:2
1649 [2024/8/18 15:17:42] [766][I/USB] read lba:65
1650 [2024/8/18 15:17:42] [766][I/USB] event:2
1651 [2024/8/18 15:17:42] [766][I/USB] read lba:66
1652 [2024/8/18 15:17:42] [778][I/USB] event:2
1653 [2024/8/18 15:17:42] [778][I/USB] read lba:67
```

##### 执行格式化操作

1. 发送CBW, SCSI Command: 0x2a(WRITE(10)) LUN:0X00
    - Signature: 0x43425355 签名
    - Tag: 0X12B1C010
    - Data Transfer Length: 512
    - flag: 0x00
        - target: 0x00
        - lun: 0x00
        - CDB Length: 10
    - CDB: 0x2a WRITE(10)
        - LUN: 0x00
        - wrprotect: 0x00
        - dpo: 0x00
        - fua: 0x00
        - rarc: 0x00
        - Logical Block Address: 0x00000000
        - Group Number: 0x00
        - Transfer Length: 1
        - Control: 0x00
2. 对扇区写入数据
3. 设备回复good
4. 主机使用read(10)读取写入扇区数据,确保写入成功

```log
[55 53 42 43 10 c0 b1 12 00 02 00 00 00 00 0a 2a 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00]
[16:16:11] [896][I/USB] Decode CB:0x2a
[16:16:11] [896][I/USB] lba: 0x0000
[16:16:11] [903][I/USB] nsectors: 0x01
[16:16:11] [903][I/USB] event:1

// 主机传输写入数据
0000   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
0010   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
0020   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
0030   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
0040   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
0050   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
0060   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
0070   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
0080   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
0090   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00a0   00 00 00 00 00 00 00 00 00 00 7a 00 68 00 2d 00
00b0   43 00 4e 00 00 00 00 00 00 00 00 00 00 00 00 00
```

5. 写入末尾扇区数据,回复good,写入全0

```log
[16:16:11] [903][I/USB] Decode CB:0x2a
[16:16:11] [909][I/USB] lba: 0x03e7
[16:16:11] [909][I/USB] nsectors: 0x01
```

6. 写入LBA2,3个扇区数据;写入LBA5,三个扇区数据

```log
[2024/8/18 16:16:11] [915][I/USB] Decode CB:0x2a
[2024/8/18 16:16:11] [915][I/USB] lba: 0x0002
[2024/8/18 16:16:11] [915][I/USB] nsectors: 0x03
[2024/8/18 16:16:11] [927][I/USB] Decode CB:0x2a
[2024/8/18 16:16:11] [927][I/USB] lba: 0x0005
[2024/8/18 16:16:11] [935][I/USB] nsectors: 0x03

0000   f8 ff ff 00 00 00 00 00 00 00 00 00 00 00 00 00
```

7. 写入LBA8,32个扇区数据;写入全零数据

```log
[16:16:11] [941][I/USB] Decode CB:0x2a
[16:16:11] [941][I/USB] lba: 0x0008
[16:16:11] [949][I/USB] nsectors: 0x20
```

#### 数据写入过程(创建文本)
1. 创建FAT12文件系统,写入MBR数据,对LBA0~1扇区写入数据
    - LBA0扇区末尾: 55 aa
    - 引导代码: 位于数据的前446字节，用于启动操作系统。
    - 分区表: 包含四个分区条目，每个条目16字节，总共64字节。每个条目描述一个分区的起始和结束位置、类型等信息。
    - 引导标志: 位于数据的最后两个字节（0x55AA），表示这是一个有效的MBR。

```log
[16:16:12] [033][I/USB] Decode CB:0x2a
[16:16:12] [033][I/USB] lba: 0x0000
[16:16:12] [046][I/USB] nsectors: 0x02
0000   eb 3c 90 4d 53 44 4f 53 35 2e 30 00 02 01 02 00   .<.MSDOS5.0.....
0010   02 00 02 e8 03 f8 03 00 01 00 01 00 00 00 00 00   ................
0020   00 00 00 00 80 00 29 55 fa e2 ea 4e 4f 20 4e 41   ......)U...NO NA
0030   4d 45 20 20 20 20 46 41 54 31 32 20 20 20 33 c9   ME    FAT12   3.
0040   8e d1 bc f0 7b 8e d9 b8 00 20 8e c0 fc bd 00 7c   ....{.... .....|
0050   38 4e 24 7d 24 8b c1 99 e8 3c 01 72 1c 83 eb 3a   8N$}$....<.r...:
0060   66 a1 1c 7c 26 66 3b 07 26 8a 57 fc 75 06 80 ca   f..|&f;.&.W.u...
0070   02 88 56 02 80 c3 10 73 eb 33 c9 8a 46 10 98 f7   ..V....s.3..F...
0080   66 16 03 46 1c 13 56 1e 03 46 0e 13 d1 8b 76 11   f..F..V..F....v.
0090   60 89 46 fc 89 56 fe b8 20 00 f7 e6 8b 5e 0b 03   `.F..V.. ....^..
00a0   c3 48 f7 f3 01 46 fc 11 4e fe 61 bf 00 00 e8 e6   .H...F..N.a.....
00b0   00 72 39 26 38 2d 74 17 60 b1 0b be a1 7d f3 a6   .r9&8-t.`....}..
00c0   61 74 32 4e 74 09 83 c7 20 3b fb 72 e6 eb dc a0   at2Nt... ;.r....
00d0   fb 7d b4 7d 8b f0 ac 98 40 74 0c 48 74 13 b4 0e   .}.}....@t.Ht...
00e0   bb 07 00 cd 10 eb ef a0 fd 7d eb e6 a0 fc 7d eb   .........}....}.
00f0   e1 cd 16 cd 19 26 8b 55 1a 52 b0 01 bb 00 00 e8   .....&.U.R......
0100   3b 00 72 e8 5b 8a 56 24 be 0b 7c 8b fc c7 46 f0   ;.r.[.V$..|...F.
0110   3d 7d c7 46 f4 29 7d 8c d9 89 4e f2 89 4e f6 c6   =}.F.)}...N..N..
0120   06 96 7d cb ea 03 00 00 20 0f b6 c8 66 8b 46 f8   ..}..... ...f.F.
0130   66 03 46 1c 66 8b d0 66 c1 ea 10 eb 5e 0f b6 c8   f.F.f..f....^...
0140   4a 4a 8a 46 0d 32 e4 f7 e2 03 46 fc 13 56 fe eb   JJ.F.2....F..V..
0150   4a 52 50 06 53 6a 01 6a 10 91 8b 46 18 96 92 33   JRP.Sj.j...F...3
0160   d2 f7 f6 91 f7 f6 42 87 ca f7 76 1a 8a f2 8a e8   ......B...v.....
0170   c0 cc 02 0a cc b8 01 02 80 7e 02 0e 75 04 b4 42   .........~..u..B
0180   8b f4 8a 56 24 cd 13 61 61 72 0b 40 75 01 42 03   ...V$..aar.@u.B.
0190   5e 0b 49 75 06 f8 c3 41 bb 00 00 60 66 6a 00 eb   ^.Iu...A...`fj..
01a0   b0 42 4f 4f 54 4d 47 52 20 20 20 20 0d 0a 52 65   .BOOTMGR    ..Re
01b0   6d 6f 76 65 20 64 69 73 6b 73 20 6f 72 20 6f 74   move disks or ot
01c0   68 65 72 20 6d 65 64 69 61 2e ff 0d 0a 44 69 73   her media....Dis
01d0   6b 20 65 72 72 6f 72 ff 0d 0a 50 72 65 73 73 20   k error...Press 
01e0   61 6e 79 20 6b 65 79 20 74 6f 20 72 65 73 74 61   any key to resta
01f0   72 74 0d 0a 00 00 00 00 00 00 00 ac cb d8 55 aa   rt............U.
```

2. 写入根目录数据,对LBA8~16扇区写入数据

```log
[16:16:12] [068][I/USB] Decode CB:0x2a
[16:16:12] [068][I/USB] lba: 0x0008
[16:16:12] [082][I/USB] nsectors: 0x08

0000   42 20 00 49 00 6e 00 66 00 6f 00 0f 00 72 72 00   B .I.n.f.o...rr.
0010   6d 00 61 00 74 00 69 00 6f 00 00 00 6e 00 00 00   m.a.t.i.o...n...
0020   01 53 00 79 00 73 00 74 00 65 00 0f 00 72 6d 00   .S.y.s.t.e...rm.
0030   20 00 56 00 6f 00 6c 00 75 00 00 00 6d 00 65 00    .V.o.l.u...m.e.
0040   53 59 53 54 45 4d 7e 31 20 20 20 16 00 06 06 82   SYSTEM~1   .....
0050   12 59 12 59 00 00 07 82 12 59 02 00 00 00 00 00   .Y.Y.....Y......
```

3. 写入数据内容,对LBA28~29扇区写入数据

```log
[16:16:12] [120][I/USB] Decode CB:0x2a
[16:16:12] [120][I/USB] lba: 0x0028
[16:16:12] [120][I/USB] nsectors: 0x01
写入LAB28扇区数据
0000   1b 00 40 e5 1d 12 83 e6 ff ff 00 00 00 00 09 00   ..@.............
0010   00 01 00 0b 00 02 03 00 02 00 00 2e 20 20 20 20   ............    
0020   20 20 20 20 20 20 10 00 06 06 82 12 59 12 59 00         ......Y.Y.
0030   00 07 82 12 59 02 00 00 00 00 00 2e 2e 20 20 20   ....Y........   
0040   20 20 20 20 20 20 10 00 06 06 82 12 59 12 59 00         ......Y.Y.
0050   00 07 82 12 59 00 00 00 00 00 00 42 74 00 00 00   ....Y......Bt...
0060   ff ff ff ff ff ff 0f 00 ce ff ff ff ff ff ff ff   ................
0070   ff ff ff ff ff 00 00 ff ff ff ff 01 57 00 50 00   ............W.P.
0080   53 00 65 00 74 00 0f 00 ce 74 00 69 00 6e 00 67   S.e.t....t.i.n.g
0090   00 73 00 2e 00 00 00 64 00 61 00 57 50 53 45 54   .s.....d.a.WPSET
00a0   54 7e 31 44 41 54 20 00 0a 06 82 12 59 12 59 00   T~1DAT .....Y.Y.
00b0   00 07 82 12 59 03 00 0c 00 00 00 42 47 00 75 00   ....Y......BG.u.
00c0   69 00 64 00 00 00 0f 00 ff ff ff ff ff ff ff ff   i.d.............
00d0   ff ff ff ff ff 00 00 ff ff ff ff 01 49 00 6e 00   ............I.n.
00e0   64 00 65 00 78 00 0f 00 ff 65 00 72 00 56 00 6f   d.e.x....e.r.V.o
00f0   00 6c 00 75 00 00 00 6d 00 65 00 49 4e 44 45 58   .l.u...m.e.INDEX
0100   45 7e 31 20 20 20 20 00 1a 07 82 12 59 12 59 00   E~1    .....Y.Y.
0110   00 08 82 12 59 04 00 4c 00 00 00 00 00 00 00 00   ....Y..L........

[16:16:12] [150][I/USB] Decode CB:0x2a
[16:16:12] [150][I/USB] lba: 0x0029
[16:16:12] [150][I/USB] nsectors: 0x01

0000   1b 00 40 e5 1d 12 83 e6 ff ff 00 00 00 00 09 00   ..@.............
0010   00 01 00 0b 00 02 03 00 02 00 00 0c 00 00 00 31   ...............1
0020   30 eb e4 b1 a8 94 17 00 00 00 00 00 00 00 00 00   0...............
```

4. 写入文件数据,对LBA42扇区写入数据

    - {7A10627C-EB63-4B65-B8F5-3C36782DF3DF}
    - 写入GUID （全局唯一标识符）

```log
0000   7b 00 37 00 41 00 31 00 30 00 36 00 32 00 37 00   {.7.A.1.0.6.2.7.
0010   43 00 2d 00 45 00 42 00 36 00 33 00 2d 00 34 00   C.-.E.B.6.3.-.4.
0020   42 00 36 00 35 00 2d 00 42 00 38 00 46 00 35 00   B.6.5.-.B.8.F.5.
0030   2d 00 33 00 43 00 33 00 36 00 37 00 38 00 32 00   -.3.C.3.6.7.8.2.
0040   44 00 46 00 33 00 44 00 46 00 7d 00 00 00 00 00   D.F.3.D.F.}.....
```

5. 在目录中添加文件索引,对LBA8~16写入数据
    - 写入文件索引,`123.txt`文件索引

```log
127 [2024/8/18 16:16:17] [106][I/USB] Decode CB:0x2a
128 [2024/8/18 16:16:17] [106][I/USB] lba: 0x0008
129 [2024/8/18 16:16:17] [119][I/USB] nsectors: 0x08

0000   42 20 00 49 00 6e 00 66 00 6f 00 0f 00 72 72 00   B .I.n.f.o...rr.
0010   6d 00 61 00 74 00 69 00 6f 00 00 00 6e 00 00 00   m.a.t.i.o...n...
0020   01 53 00 79 00 73 00 74 00 65 00 0f 00 72 6d 00   .S.y.s.t.e...rm.
0030   20 00 56 00 6f 00 6c 00 75 00 00 00 6d 00 65 00    .V.o.l.u...m.e.
0040   53 59 53 54 45 4d 7e 31 20 20 20 16 00 06 06 82   SYSTEM~1   .....
0050   12 59 12 59 00 00 07 82 12 59 02 00 00 00 00 00   .Y.Y.....Y......
0060   e5 b0 65 fa 5e 20 00 87 65 2c 67 0f 00 d2 87 65   ..e.^ ..e,g....e
0070   63 68 2e 00 74 00 78 00 74 00 00 00 00 00 ff ff   ch..t.x.t.......
0080   e5 c2 bd a8 ce c4 7e 31 54 58 54 20 00 6d 08 82   ......~1TXT .m..
0090   12 59 12 59 00 00 09 82 12 59 00 00 00 00 00 00   .Y.Y.....Y......
00a0   31 32 33 20 20 20 20 20 54 58 54 20 10 6d 08 82   123     TXT .m..
00b0   12 59 12 59 00 00 09 82 12 59 00 00 00 00 00 00   .Y.Y.....Y......
```

6. 在文件扇区写入数据,对LBA43写入数据

```log
[16:16:21] [708][I/USB] Decode CB:0x2a
[16:16:21] [708][I/USB] lba: 0x002b
[16:16:21] [708][I/USB] nsectors: 0x01

0000   30 30 30 30 20 20 20 35 35 20 35 33 20 34 32 20   0000   55 53 42 
0010   34 33 20 36 30 20 39 35 20 63 61 20 31 36 20 30   43 60 95 ca 16 0
0020   30 20 30 30 20 30 30 20 30 30 20 30 30 20 30 30   0 00 00 00 00 00
0030   20 30 36 20 31 65 0d 0a 30 30 31 30 20 20 20 30    06 1e..0010   0
0040   30 20 30 30 20 30 30 20 30 31 20 30 30 20 30 30   0 00 00 01 00 00
0050   20 30 30 20 30 30 20 30 30 20 30 30 20 30 30 20    00 00 00 00 00 
0060   30 30 20 30 30 20 30 30 20 30 30 0d 0a 00 00 00   00 00 00 00.....
```

#### U盘弹出操作

- 使用`SCSI_CMD_PREVENTMEDIAREMOVAL`命令进行交互完成,任务栏弹出使用的命令
- 使用`SCSI_CMD_STARTSTOPUNIT`,盘符执行弹出使用

### msc function

#### init
```c
void msc_ram_init(uint8_t busid, uint32_t reg_base)
{
    usbd_desc_register(busid, msc_ram_descriptor);
    usbd_add_interface(busid, usbd_msc_init_intf(busid, &intf0, MSC_OUT_EP, MSC_IN_EP));

    usbd_initialize(busid, reg_base, usbd_event_handler);
}
```

#### usbd_msc_init_intf

```c
struct usbd_interface *usbd_msc_init_intf(uint8_t busid, struct usbd_interface *intf, const uint8_t out_ep, const uint8_t in_ep)
{
    intf->class_interface_handler = msc_storage_class_interface_request_handler;
    intf->class_endpoint_handler = NULL;
    intf->vendor_handler = NULL;
    intf->notify_handler = msc_storage_notify_handler;

    mass_ep_data[busid][MSD_OUT_EP_IDX].ep_addr = out_ep;
    mass_ep_data[busid][MSD_OUT_EP_IDX].ep_cb = mass_storage_bulk_out;
    mass_ep_data[busid][MSD_IN_EP_IDX].ep_addr = in_ep;
    mass_ep_data[busid][MSD_IN_EP_IDX].ep_cb = mass_storage_bulk_in;

    usbd_add_endpoint(busid, &mass_ep_data[busid][MSD_OUT_EP_IDX]);
    usbd_add_endpoint(busid, &mass_ep_data[busid][MSD_IN_EP_IDX]);

    memset((uint8_t *)&g_usbd_msc[busid], 0, sizeof(struct usbd_msc_priv));

    usdb_msc_set_max_lun(busid);//设置最大LUN,定义了 USB 大容量存储类 （MSC） 设备可以支持的最大逻辑单元号 （LUN） 数。
    for (uint8_t i = 0u; i <= g_usbd_msc[busid].max_lun; i++) {
        usbd_msc_get_cap(busid, i, &g_usbd_msc[busid].scsi_blk_nbr[i], &g_usbd_msc[busid].scsi_blk_size[i]);

        if (g_usbd_msc[busid].scsi_blk_size[i] > CONFIG_USBDEV_MSC_MAX_BUFSIZE) {
            USB_LOG_ERR("msc block buffer overflow\r\n");
            return NULL;
        }
    }

    return intf;
}
```

#### usbd_msc_get_cap

- 需要自行实现,以下为示例

```c
void usbd_msc_get_cap(uint8_t busid, uint8_t lun, uint32_t *block_num, uint32_t *block_size)
{
    *block_num = 1000; //Pretend having so many buffer,not has actually.
    *block_size = BLOCK_SIZE;
}
```

#### msc_storage_notify_handler

```c
void msc_storage_notify_handler(uint8_t busid, uint8_t event, void *arg)
{
    switch (event) {
        case USBD_EVENT_INIT:
#ifdef CONFIG_USBDEV_MSC_THREAD
            g_usbd_msc[busid].usbd_msc_mq = usb_osal_mq_create(1);
            if (g_usbd_msc[busid].usbd_msc_mq == NULL) {
                USB_LOG_ERR("No memory to alloc for g_usbd_msc[busid].usbd_msc_mq\r\n");
            }
            g_usbd_msc[busid].usbd_msc_thread = usb_osal_thread_create("usbd_msc", CONFIG_USBDEV_MSC_STACKSIZE, CONFIG_USBDEV_MSC_PRIO, usbdev_msc_thread, (void *)busid);
            if (g_usbd_msc[busid].usbd_msc_thread == NULL) {
                USB_LOG_ERR("No memory to alloc for g_usbd_msc[busid].usbd_msc_thread\r\n");
            }
#endif
            break;
        case USBD_EVENT_DEINIT:
#ifdef CONFIG_USBDEV_MSC_THREAD
            if (g_usbd_msc[busid].usbd_msc_mq) {
                usb_osal_mq_delete(g_usbd_msc[busid].usbd_msc_mq);
            }
            if (g_usbd_msc[busid].usbd_msc_thread) {
                usb_osal_thread_delete(g_usbd_msc[busid].usbd_msc_thread);
            }
#endif
            break;
        case USBD_EVENT_RESET:
            usbd_msc_reset(busid);
            break;
        case USBD_EVENT_CONFIGURED:
            USB_LOG_DBG("Start reading cbw\r\n");
            usbd_ep_start_read(busid, mass_ep_data[busid][MSD_OUT_EP_IDX].ep_addr, (uint8_t *)&g_usbd_msc[busid].cbw, USB_SIZEOF_MSC_CBW);
            break;

        default:
            break;
    }
}
```


#### mass_storage_bulk_out

- out端点回调函数,根据`stage`状态执行不同操作

```c
void mass_storage_bulk_out(uint8_t busid, uint8_t ep, uint32_t nbytes)
{
    switch (g_usbd_msc[busid].stage) {
        case MSC_READ_CBW:
            if (SCSI_CBWDecode(busid, nbytes) == false) {
                USB_LOG_ERR("Command:0x%02x decode err\r\n", g_usbd_msc[busid].cbw.CB[0]);
                usbd_msc_bot_abort(busid);
                return;
            }
            break;
        case MSC_DATA_OUT:
            switch (g_usbd_msc[busid].cbw.CB[0]) {
                case SCSI_CMD_WRITE10:
                case SCSI_CMD_WRITE12:
#ifdef CONFIG_USBDEV_MSC_THREAD
                    g_usbd_msc[busid].nbytes = nbytes;
                    usb_osal_mq_send(g_usbd_msc[busid].usbd_msc_mq, MSC_DATA_OUT);
#else
                    if (SCSI_processWrite(busid, nbytes) == false) {
                        usbd_msc_send_csw(busid, CSW_STATUS_CMD_FAILED); /* send fail status to host,and the host will retry*/
                    }
#endif
                    break;
                default:
                    break;
            }
            break;
        default:
            break;
    }
}
```

##### SCSI_CBWDecode

- 解码CBW,并根据命令执行不同操作

```c
static bool SCSI_CBWDecode(uint8_t busid, uint32_t nbytes)
{
    uint8_t *buf2send = g_usbd_msc[busid].block_buffer;
    uint32_t len2send = 0;
    bool ret = false;

    if (nbytes != sizeof(struct CBW)) {
        USB_LOG_ERR("size != sizeof(cbw)\r\n");
        SCSI_SetSenseData(busid, SCSI_KCQIR_INVALIDCOMMAND);
        return false;
    }

    g_usbd_msc[busid].csw.dTag = g_usbd_msc[busid].cbw.dTag;
    g_usbd_msc[busid].csw.dDataResidue = g_usbd_msc[busid].cbw.dDataLength;

    if ((g_usbd_msc[busid].cbw.dSignature != MSC_CBW_Signature) || (g_usbd_msc[busid].cbw.bCBLength < 1) || (g_usbd_msc[busid].cbw.bCBLength > 16)) {
        SCSI_SetSenseData(busid, SCSI_KCQIR_INVALIDCOMMAND);
        return false;
    } else {
        USB_LOG_DBG("Decode CB:0x%02x\r\n", g_usbd_msc[busid].cbw.CB[0]);
        switch (g_usbd_msc[busid].cbw.CB[0]) {
            default:
                SCSI_SetSenseData(busid, SCSI_KCQIR_INVALIDCOMMAND);
                USB_LOG_WRN("unsupported cmd:0x%02x\r\n", g_usbd_msc[busid].cbw.CB[0]);
                ret = false;
                break;
        }
    }
    if (ret) {
        if (g_usbd_msc[busid].stage == MSC_READ_CBW) {
            if (len2send) {
                USB_LOG_DBG("Send info len:%d\r\n", len2send);
                usbd_msc_send_info(busid, buf2send, len2send);
            } else {
                usbd_msc_send_csw(busid, CSW_STATUS_CMD_PASSED);
            }
        }
    }
    return ret;
}
```

###### SCSI_CMD_INQUIRY 0x12

- copy默认的inquiry信息,并回复

```c
        if (g_usbd_msc[busid].cbw.CB[4] < SCSIRESP_INQUIRY_SIZEOF) {
            data_len = g_usbd_msc[busid].cbw.CB[4];
        }
        memcpy(*data, (uint8_t *)inquiry, data_len);

    *len = data_len;
```


###### usbd_msc_send_info

- 发送信息

```c
static void usbd_msc_send_info(uint8_t busid, uint8_t *buffer, uint8_t size)
{
    size = MIN(size, g_usbd_msc[busid].cbw.dDataLength);

    /* updating the State Machine , so that we send CSW when this
	 * transfer is complete, ie when we get a bulk in callback
	 */
    g_usbd_msc[busid].stage = MSC_SEND_CSW;

    usbd_ep_start_write(busid, mass_ep_data[busid][MSD_IN_EP_IDX].ep_addr, buffer, size);

    g_usbd_msc[busid].csw.dDataResidue -= size;
    g_usbd_msc[busid].csw.bStatus = CSW_STATUS_CMD_PASSED;
}
```

#### mass_storage_bulk_in

- in端点回调函数,根据`stage`状态执行不同操作

```c
void mass_storage_bulk_in(uint8_t busid, uint8_t ep, uint32_t nbytes)
{
    switch (g_usbd_msc[busid].stage) {
        case MSC_DATA_IN:
            switch (g_usbd_msc[busid].cbw.CB[0]) {
                case SCSI_CMD_READ10:
                case SCSI_CMD_READ12:
#ifdef CONFIG_USBDEV_MSC_THREAD
                    usb_osal_mq_send(g_usbd_msc[busid].usbd_msc_mq, MSC_DATA_IN);
#else
                    if (SCSI_processRead(busid) == false) {
                        usbd_msc_send_csw(busid, CSW_STATUS_CMD_FAILED); /* send fail status to host,and the host will retry*/
                        return;
                    }
#endif
                    break;
                default:
                    break;
            }
            break;
        /*the device has to send a CSW*/
        case MSC_SEND_CSW:
            usbd_msc_send_csw(busid, CSW_STATUS_CMD_PASSED);
            break;

        /*the host has received the CSW*/
        case MSC_WAIT_CSW:
            g_usbd_msc[busid].stage = MSC_READ_CBW;
            USB_LOG_DBG("Start reading cbw\r\n");
            usbd_ep_start_read(busid, mass_ep_data[busid][MSD_OUT_EP_IDX].ep_addr, (uint8_t *)&g_usbd_msc[busid].cbw, USB_SIZEOF_MSC_CBW);
            break;

        default:
            break;
    }
}
```

##### MSC_SEND_CSW

```c
usbd_msc_send_csw(busid, CSW_STATUS_CMD_PASSED);
```

#### usbd_msc_send_csw

- 发送CSW,并设置状态为`MSC_WAIT_CSW`,等待主机发送批量传输

```c
static void usbd_msc_send_csw(uint8_t busid, uint8_t CSW_Status)
{
    g_usbd_msc[busid].csw.dSignature = MSC_CSW_Signature;
    g_usbd_msc[busid].csw.bStatus = CSW_Status;

    /* updating the State Machine , so that we wait CSW when this
	 * transfer is complete, ie when we get a bulk in callback
	 */
    g_usbd_msc[busid].stage = MSC_WAIT_CSW;

    USB_LOG_DBG("Send csw\r\n");
    usbd_ep_start_write(busid, mass_ep_data[busid][MSD_IN_EP_IDX].ep_addr, (uint8_t *)&g_usbd_msc[busid].csw, sizeof(struct CSW));
}
```

#### SCSI_processRead

1. 判断最小传输长度
2. 通过`usbd_msc_sector_read`接口读取数据
3. 更新开始扇区,剩余扇区,数据长度
4. CBW需要获取扇区数为0,设置状态为`MSC_SEND_CSW`
5. 通过`usbd_ep_start_write`发送数据

```c
static bool SCSI_processRead(uint8_t busid)
{
    uint32_t transfer_len;

    USB_LOG_DBG("read lba:%d\r\n", g_usbd_msc[busid].start_sector);

    transfer_len = MIN(g_usbd_msc[busid].nsectors * g_usbd_msc[busid].scsi_blk_size[g_usbd_msc[busid].cbw.bLUN], CONFIG_USBDEV_MSC_MAX_BUFSIZE);

    if (usbd_msc_sector_read(busid, g_usbd_msc[busid].cbw.bLUN, g_usbd_msc[busid].start_sector, g_usbd_msc[busid].block_buffer, transfer_len) != 0) {
        SCSI_SetSenseData(busid, SCSI_KCQHE_UREINRESERVEDAREA);
        return false;
    }

    g_usbd_msc[busid].start_sector += (transfer_len / g_usbd_msc[busid].scsi_blk_size[g_usbd_msc[busid].cbw.bLUN]);
    g_usbd_msc[busid].nsectors -= (transfer_len / g_usbd_msc[busid].scsi_blk_size[g_usbd_msc[busid].cbw.bLUN]);
    g_usbd_msc[busid].csw.dDataResidue -= transfer_len;

    if (g_usbd_msc[busid].nsectors == 0) {
        g_usbd_msc[busid].stage = MSC_SEND_CSW;
    }

    usbd_ep_start_write(busid, mass_ep_data[busid][MSD_IN_EP_IDX].ep_addr, g_usbd_msc[busid].block_buffer, transfer_len);

    return true;
}
```

#### usbd_msc_sector_read

- 需要自行实现,以下为示例

```c
int usbd_msc_sector_read(uint8_t busid, uint8_t lun, uint32_t sector, uint8_t *buffer, uint32_t length)
{
    if (sector < BLOCK_COUNT)
        memcpy(buffer, mass_block[sector].BlockSpace, length);
    return 0;
}
```

### usbd_msc_sector_write

- 需要自行实现,以下为示例

```c
int usbd_msc_sector_write(uint8_t busid, uint8_t lun, uint32_t sector, uint8_t *buffer, uint32_t length)
{
    if (sector < BLOCK_COUNT)
        memcpy(mass_block[sector].BlockSpace, buffer, length);
    return 0;
}
```

### msc_ram_descriptor

- bInterfaceClass : USB_DEVICE_CLASS_MASS_STORAGE 0x08
- bInterfaceSubClass : MSC_SUBCLASS_SCSI 0x06
- bInterfaceProtocol : MSC_PROTOCOL_BULK_ONLY 0x50
    - USB大容量存储类仅大容量(BBB)传输

- 设置了两个端点,一个接收,一个发送

```c
#define MSC_DESCRIPTOR_INIT(bFirstInterface, out_ep, in_ep, wMaxPacketSize, str_idx) \
    /* Interface */                                              \
    0x09,                          /* bLength */                 \
    USB_DESCRIPTOR_TYPE_INTERFACE, /* bDescriptorType */         \
    bFirstInterface,               /* bInterfaceNumber */        \
    0x00,                          /* bAlternateSetting */       \
    0x02,                          /* bNumEndpoints */           \
    USB_DEVICE_CLASS_MASS_STORAGE, /* bInterfaceClass */         \
    MSC_SUBCLASS_SCSI,             /* bInterfaceSubClass */      \
    MSC_PROTOCOL_BULK_ONLY,        /* bInterfaceProtocol */      \
    str_idx,                       /* iInterface */              \
    0x07,                          /* bLength */                 \
    USB_DESCRIPTOR_TYPE_ENDPOINT,  /* bDescriptorType */         \
    out_ep,                        /* bEndpointAddress */        \
    0x02,                          /* bmAttributes */            \
    WBVAL(wMaxPacketSize),         /* wMaxPacketSize */          \
    0x00,                          /* bInterval */               \
    0x07,                          /* bLength */                 \
    USB_DESCRIPTOR_TYPE_ENDPOINT,  /* bDescriptorType */         \
    in_ep,                         /* bEndpointAddress */        \
    0x02,                          /* bmAttributes */            \
    WBVAL(wMaxPacketSize),         /* wMaxPacketSize */          \
    0x00                           /* bInterval */
```

```c
const uint8_t msc_ram_descriptor[] = {
    USB_DEVICE_DESCRIPTOR_INIT(USB_2_0, 0x00, 0x00, 0x00, USBD_VID, USBD_PID, 0x0200, 0x01),
    USB_CONFIG_DESCRIPTOR_INIT(USB_CONFIG_SIZE, 0x01, 0x01, USB_CONFIG_BUS_POWERED, USBD_MAX_POWER),
    MSC_DESCRIPTOR_INIT(0x00, MSC_OUT_EP, MSC_IN_EP, MSC_MAX_MPS, 0x02),
    ///////////////////////////////////////
    /// string0 descriptor
    ///////////////////////////////////////
    USB_LANGID_INIT(USBD_LANGID_STRING),
    ///////////////////////////////////////
    /// string1 descriptor
    ///////////////////////////////////////
    0x14,                       /* bLength */
    USB_DESCRIPTOR_TYPE_STRING, /* bDescriptorType */
    'C', 0x00,                  /* wcChar0 */
    'h', 0x00,                  /* wcChar1 */
    'e', 0x00,                  /* wcChar2 */
    'r', 0x00,                  /* wcChar3 */
    'r', 0x00,                  /* wcChar4 */
    'y', 0x00,                  /* wcChar5 */
    'U', 0x00,                  /* wcChar6 */
    'S', 0x00,                  /* wcChar7 */
    'B', 0x00,                  /* wcChar8 */
    ///////////////////////////////////////
    /// string2 descriptor
    ///////////////////////////////////////
    0x26,                       /* bLength */
    USB_DESCRIPTOR_TYPE_STRING, /* bDescriptorType */
    'C', 0x00,                  /* wcChar0 */
    'h', 0x00,                  /* wcChar1 */
    'e', 0x00,                  /* wcChar2 */
    'r', 0x00,                  /* wcChar3 */
    'r', 0x00,                  /* wcChar4 */
    'y', 0x00,                  /* wcChar5 */
    'U', 0x00,                  /* wcChar6 */
    'S', 0x00,                  /* wcChar7 */
    'B', 0x00,                  /* wcChar8 */
    ' ', 0x00,                  /* wcChar9 */
    'M', 0x00,                  /* wcChar10 */
    'S', 0x00,                  /* wcChar11 */
    'C', 0x00,                  /* wcChar12 */
    ' ', 0x00,                  /* wcChar13 */
    'D', 0x00,                  /* wcChar14 */
    'E', 0x00,                  /* wcChar15 */
    'M', 0x00,                  /* wcChar16 */
    'O', 0x00,                  /* wcChar17 */
    ///////////////////////////////////////
    /// string3 descriptor
    ///////////////////////////////////////
    0x16,                       /* bLength */
    USB_DESCRIPTOR_TYPE_STRING, /* bDescriptorType */
    '2', 0x00,                  /* wcChar0 */
    '0', 0x00,                  /* wcChar1 */
    '2', 0x00,                  /* wcChar2 */
    '2', 0x00,                  /* wcChar3 */
    '1', 0x00,                  /* wcChar4 */
    '2', 0x00,                  /* wcChar5 */
    '3', 0x00,                  /* wcChar6 */
    '4', 0x00,                  /* wcChar7 */
    '5', 0x00,                  /* wcChar8 */
    '6', 0x00,                  /* wcChar9 */
#ifdef CONFIG_USB_HS
    ///////////////////////////////////////
    /// device qualifier descriptor
    ///////////////////////////////////////
    0x0a,
    USB_DESCRIPTOR_TYPE_DEVICE_QUALIFIER,
    0x00,
    0x02,
    0x00,
    0x00,
    0x00,
    0x40,
    0x01,
    0x00,
#endif
    0x00
};
```

### Mass Storage Request Codes

#### Get Max LUN (GML) 0xFE

- 由USB大容量存储类仅限大容量(BBB)传输分配

### Bulk-Only Transport Protocol

- 该规范处理仅批量传输，或者换句话说，仅通过批量端点(不通过中断或控制端点)传输命令、数据和状态。此规范仅使用默认管道清除Bulk端点上的STALL条件，并发出如下所定义的特定于类的请求。本规范不要求使用中断端点。
- 该规范定义了对共享公共设备特性的逻辑单元的支持。虽然这个特性提供了必要的支持，允许类似的大容量存储设备共享一个通用的USB接口描述符，但它并不打算用于实现接口桥接设备。

#### CBW (Command Block Wrapper)

- 表 5-1 命令块包装器 (Command Block Wrapper)

| 字节 | 字段名称                | 描述 |
|------|-------------------------|-------------|
| 0-3  | dCBWSignature           | 用于识别此数据包为 CBW 的签名。 |
| 4-7  | dCBWTag                 | 主机发送的标签，用于将此 CBW 与相应的 CSW 关联。 |
| 8-11 | dCBWDataTransferLength  | 主机期望在此命令中传输的数据字节数。 |
| 12   | bmCBWFlags              | 指示数据传输方向的标志。 |
| 13   | bCBWLUN                 | 与此命令关联的逻辑单元号。 |
| 14   | 保留                   | 保留 (0) |
| 15-30| 保留                   | 保留 (0) |

* **dCBWSignature**: 此字段包含 `43425355h`，用于识别传入的 CBW。
* **dCBWTag**: 用于将 CBW 与相应的 CSW 关联的唯一标识符。
    - **位 7**: 方向 - 如果 dCBWDataTransferLength 字段为零，设备应忽略此位，否则：
        - 0 = 数据从主机传输到设备（Data-Out）
        - 1 = 数据从设备传输到主机（Data-In）
    - **位 6**: 废弃。主机应将此位设置为零。
    - **位 5-0**: 保留 - 主机应将这些位设置为零。
    * **bmCBWFlags**: 指示设备是否应忽略或遵守 `bCBWCBLength` 中的值。
* **dCBWDataTransferLength**: 主机期望在 Bulk-In 或 Bulk-Out 端点（由方向位指示）上传输的数据字节数。如果此字段为零，则设备和主机在 CBW 和相应的 CSW 之间不传输数据，设备应忽略 bmCBWFlags 中的方向位的值。
* **bCBWLUN**: 对于支持多个 LUN 的设备，主机应在此字段中放置发送命令块的 LUN。否则，主机应将此字段设置为零。
* **bCBWCBLength**: 此值定义命令块的有效长度。唯一合法的值是 1 到 16（01h 到 10h）。所有其他值均为保留值。
* **CBWCB**: 设备要执行的命令块。设备应将此字段中的前 `bCBWCBLength` 字节解释为由 `bInterfaceSubClass` 标识的命令集定义的命令块。如果设备支持的命令集使用少于 16（10h）字节的命令块，则应首先传输有效字节，从偏移量 15（Fh）开始。设备应忽略 `CBWCB` 字段中偏移量（15 + `bCBWCBLength` - 1）之后的内容。

#### SCSI Command

- https://www.staff.uni-mainz.de/tacke/scsi/SCSI2-08.html

##### SCSI_CMD_INQUIRY 0x12

- 参考<<usbmassbulk_10.pdf>> 6.4.2 INQUIRY命令
- INQUIRY命令(参见表58)请求将有关逻辑单元和SCSI目标设备的信息发送到应用程序客户端。

- 表 58 INQUIRY 命令

| Byte | Bit 7 | Bit 6 | Bit 5 | Bit 4 | Bit 3 | Bit 2 | Bit 1 | Bit 0 |
|------|-------|-------|-------|-------|-------|-------|-------|-------|
| 0    | OPERATION CODE (12h) |       |       |       |       |       |       |       |
| 1    | Reserved |       |       |       |       |       | Formerly | EVPD  |
| 2    | PAGE CODE |       |       |       |       |       |       |       |
| 3 - 4 | ALLOCATION LENGTH|
| 5    | CONTROL |       |       |       |       |       |       |       |

- **EVPD（启用重要产品数据）位**：设置为 1 时，指定设备服务器应返回由页面代码字段指定的重要产品数据。如果 EVPD 位设置为 0，设备服务器应返回标准 INQUIRY 数据（见 3.6.2）。如果在 EVPD 位设置为 0 时页面代码字段不为零，则命令应以 CHECK CONDITION 状态终止，感知键设置为 ILLEGAL REQUEST，附加感知代码设置为 INVALID FIELD IN CDB。
- **CMDDT（命令支持数据）位**：此位已被 T10 委员会声明为废弃。然而，它仍然包含在内，因为某些产品可能会实现此功能。有关此位的描述，请参见 SPC-2。如果 EVPD 和 CMDDT 位都为 1，目标应返回 CHECK CONDITION 状态，感知键设置为 ILLEGAL REQUEST，附加感知代码为 Invalid Field in CDB。当 EVPD 位为 1 时，页面或操作码字段指定目标应返回的重要产品数据页面。
- **ALLOCATION LENGTH**: 如果EVPD设置为0，则分配长度至少为5，这样将返回参数数据(参见3.6.2)中的ADDITIONAL length字段。如果EVPD设置为1，则分配长度应该至少为4，这样就会返回参数数据(参见5.4)中的PAGE length字段。

- 回复的为:`Standard INQUIRY data format` 标准INQUIRY数据格式

```c
    uint8_t inquiry[SCSIRESP_INQUIRY_SIZEOF] = {
        /* 36 */

        /* LUN 0 */
        /*
         * Qualifier: 设备类型连接到逻辑单元
         * Device Type:直接存取块设备(如磁盘)
        */
        0x00,
        /*
         * RMB: 0x80 可移动介质
         * Device-type modifier: 0x00 不支持
         */
        0x80,
        /*
        * ANSI-approved version: 设备遵循SCSI的这个版本。本规范保留用于指定ANSI批准后的标准。
        * ECMA 版本: 目标未声明符合 ISO 版本的 SCSI （ISO 9316）
        * ISO 版本: 目标未声明符合 ECMA 版本的 SCSI （ECMA 111）
        */
        0x02,
        /*
         * Response Data Format: 0x02 表示数据应采用本国际标准中规定的格式。 
         * AENC: 处理器设备不支持异步事件通知
         * TrmIOP: 0x00 设备不支持 TERMINATE I/O PROCESS 消息
        */
        0x02,
        // 分配长度
        (SCSIRESP_INQUIRY_SIZEOF - 5),
        //reserverd
        0x00,
        //reserverd
        0x00,
        /*
         * RelAdr: 0x00 设备不支持相对地址
         * WBus32: 0x00 设备不支持32位总线
         * WBus16: 0x00 设备不支持16位总线
         * 如果 Wbus16 和 Wbus32 位的值均为零，则设备仅支持 8 位宽的数据传输。
         * Sync: 0x00 设备不支持同步数据传输
         * Linked: 0x00 设备不支持连接命令
         * CmdQue: 0x00 设备不支持命令队列
         * SftRe: 0x00 设备不支持软重置
        */
        0x00,
        ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', /* 供应商   : 8 bytes */
        ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', /* 产品标识 : 16 Bytes */
        ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ',
        ' ', ' ', ' ', ' ' /* 版本号      : 4 Bytes */
    };

    memcpy(&inquiry[8], CONFIG_USBDEV_MSC_MANUFACTURER_STRING, strlen(CONFIG_USBDEV_MSC_MANUFACTURER_STRING));
    memcpy(&inquiry[16], CONFIG_USBDEV_MSC_PRODUCT_STRING, strlen(CONFIG_USBDEV_MSC_PRODUCT_STRING));
    memcpy(&inquiry[32], CONFIG_USBDEV_MSC_VERSION_STRING, strlen(CONFIG_USBDEV_MSC_VERSION_STRING));
```

##### SCSI_CMD_READFORMATCAPACITIES 0x23

- 参见<<usbmass-ufi10.pdf>> 第4节
- 发送`[23 00 00 00 00 00 00 00 fc 00 00 00 00 00 00 00]`
    - CB: 0x23
    - LUN: 0x00
    - Allocation Length: 0xfc = 252
- 在收到这个命令块后，UFI设备将容量列表返回给Bulk In端点上的主机。
- `scsi_blk_size`和`scsi_blk_nbr`通过`usbd_msc_get_cap`获取

```c
static bool SCSI_readFormatCapacity(uint8_t busid, uint8_t **data, uint32_t *len)
{
    uint8_t format_capacity[SCSIRESP_READFORMATCAPACITIES_SIZEOF] = {
        0x00,
        0x00,
        0x00,
        0x08, /* Capacity List Length */
        /*Number of Blocks*/
        (uint8_t)((g_usbd_msc[busid].scsi_blk_nbr[g_usbd_msc[busid].cbw.bLUN] >> 24) & 0xff),
        (uint8_t)((g_usbd_msc[busid].scsi_blk_nbr[g_usbd_msc[busid].cbw.bLUN] >> 16) & 0xff),
        (uint8_t)((g_usbd_msc[busid].scsi_blk_nbr[g_usbd_msc[busid].cbw.bLUN] >> 8) & 0xff),
        (uint8_t)((g_usbd_msc[busid].scsi_blk_nbr[g_usbd_msc[busid].cbw.bLUN] >> 0) & 0xff),
        /*
        * 01b: Unformatted Media
        * 02b: Formatted Media
        * 03b: No Cartridge in Device
        */
        0x02, /* Descriptor Code: Formatted Media */
        0x00, 
        (uint8_t)((g_usbd_msc[busid].scsi_blk_size[g_usbd_msc[busid].cbw.bLUN] >> 8) & 0xff),
        (uint8_t)((g_usbd_msc[busid].scsi_blk_size[g_usbd_msc[busid].cbw.bLUN] >> 0) & 0xff),  /* Block Length */
    };

    memcpy(*data, (uint8_t *)format_capacity, SCSIRESP_READFORMATCAPACITIES_SIZEOF);
    *len = SCSIRESP_READFORMATCAPACITIES_SIZEOF;
    return true;
}
```

##### SCSI_CMD_READCAPACITY10 0x25

- READ capacity命令允许主机请求当前安装的介质的容量

```c
static bool SCSI_readCapacity10(uint8_t busid, uint8_t **data, uint32_t *len)
{
    if (g_usbd_msc[busid].cbw.dDataLength == 0U) {
        SCSI_SetSenseData(busid, SCSI_KCQIR_INVALIDCOMMAND);
        return false;
    }

    uint8_t capacity10[SCSIRESP_READCAPACITY10_SIZEOF] = {
        (uint8_t)(((g_usbd_msc[busid].scsi_blk_nbr[g_usbd_msc[busid].cbw.bLUN] - 1) >> 24) & 0xff),
        (uint8_t)(((g_usbd_msc[busid].scsi_blk_nbr[g_usbd_msc[busid].cbw.bLUN] - 1) >> 16) & 0xff),
        (uint8_t)(((g_usbd_msc[busid].scsi_blk_nbr[g_usbd_msc[busid].cbw.bLUN] - 1) >> 8) & 0xff),
        (uint8_t)(((g_usbd_msc[busid].scsi_blk_nbr[g_usbd_msc[busid].cbw.bLUN] - 1) >> 0) & 0xff),

        (uint8_t)((g_usbd_msc[busid].scsi_blk_size[g_usbd_msc[busid].cbw.bLUN] >> 24) & 0xff),
        (uint8_t)((g_usbd_msc[busid].scsi_blk_size[g_usbd_msc[busid].cbw.bLUN] >> 16) & 0xff),
        (uint8_t)((g_usbd_msc[busid].scsi_blk_size[g_usbd_msc[busid].cbw.bLUN] >> 8) & 0xff),
        (uint8_t)((g_usbd_msc[busid].scsi_blk_size[g_usbd_msc[busid].cbw.bLUN] >> 0) & 0xff),
    };

    memcpy(*data, (uint8_t *)capacity10, SCSIRESP_READCAPACITY10_SIZEOF);
    *len = SCSIRESP_READCAPACITY10_SIZEOF;
    return true;
}
```

##### SCSI_CMD_MODESENSE6 0x1A

- MODE SENSE(6)命令为设备服务器向应用程序客户机报告参数提供了一种方法。

|      |   |   |   |   |   |   |   |
|------|---|---|---|---|---|---|---|
| **Bit**    | **7** | **6** | **5** | **4** | **3** | **2** | **1** | **0** |
| **0**      | OPERATION CODE (1Ah) ||||||
| **1**      || Reserved || DBD || Reserved ||
| **2**      || PC PAGE CODE||||||
| **3**      ||SUBPAGE CODE|
| **4**      || ALLOCATION LENGTH||||||
| **5**      || CONTROL|||||||

- **DBD（禁用块描述符）位**：如果 DBD 位设置为 1，则设备服务器应返回参数数据，其中不包含块描述符。如果 DBD 位设置为 0，则设备服务器应返回参数数据，其中包含块描述符。
- **PC（页面控制）字段**：此字段指定设备服务器应返回的参数数据页面。如果 PC 字段为零，则设备服务器应返回当前值。如果 PC 字段为 1，则设备服务器应返回默认值。如果 PC 字段为 2，则设备服务器应返回保存值。如果 PC 字段为 3，则设备服务器应返回更改值。
- **PAGE CODE 字段**：指定要返回的模式页
- **SUBPAGE CODE 字段**：指定要返回的模式页的子页
- **ALLOCATION LENGTH 字段**：此字段指定设备服务器应返回的参数数据的长度（以字节为单位）。如果 ALLOCATION LENGTH 字段为零，则设备服务器应返回参数数据的长度，以便填充主机分配的数据缓冲区。如果 ALLOCATION LENGTH 字段为非零值，则设备服务器应返回参数数据的长度，以便填充主机分配的数据缓冲区，但不得超过 ALLOCATION LENGTH 字段中指定的长度。
- **CONTROL 字段**：此字段包含用于错误检测和纠正的 CRC 或校验和。

```c
static bool SCSI_modeSense6(uint8_t busid, uint8_t **data, uint32_t *len)
{
    uint8_t data_len = 4;
    if (g_usbd_msc[busid].cbw.dDataLength == 0U) {
        SCSI_SetSenseData(busid, SCSI_KCQIR_INVALIDCOMMAND);
        return false;
    }
    if (g_usbd_msc[busid].cbw.CB[4] < SCSIRESP_MODEPARAMETERHDR6_SIZEOF) {
        data_len = g_usbd_msc[busid].cbw.CB[4];
    }

    uint8_t sense6[SCSIRESP_MODEPARAMETERHDR6_SIZEOF] = { 0x03, 0x00, 0x00, 0x00 };

    if (g_usbd_msc[busid].readonly) {
        sense6[2] = 0x80;
    }
    memcpy(*data, (uint8_t *)sense6, data_len);
    *len = data_len;
    return true;
}
```

##### SCSI_CMD_READ10 0x28

- READ(10)命令(参见表97)请求设备服务器读取指定的逻辑块并将它们传输到data-in缓冲区。读取的每个逻辑块包括用户数据，如果介质已启用保护信息进行格式化，还包括保护信息。传输的每个逻辑块包括用户数据，也可能包括基于RDPROTECT字段和介质格式的保护信息。应该返回最近写入地址逻辑块的数据值

- 获取传输过来需要读取的LBA和读取的块数,并判断是否超出范围
- 判断`dDataLength`是否和`nsectors * scsi_blk_size`相等
- 设置`stage`为`MSC_DATA_IN`,并发送`MSC_DATA_IN`消息

```c
static bool SCSI_read10(uint8_t busid, uint8_t **data, uint32_t *len)
{
    if (((g_usbd_msc[busid].cbw.bmFlags & 0x80U) != 0x80U) || (g_usbd_msc[busid].cbw.dDataLength == 0U)) {
        SCSI_SetSenseData(busid, SCSI_KCQIR_INVALIDCOMMAND);
        return false;
    }

    g_usbd_msc[busid].start_sector = GET_BE32(&g_usbd_msc[busid].cbw.CB[2]); /* Logical Block Address of First Block */
    USB_LOG_DBG("lba: 0x%04x\r\n", g_usbd_msc[busid].start_sector);

    g_usbd_msc[busid].nsectors = GET_BE16(&g_usbd_msc[busid].cbw.CB[7]); /* Number of Blocks to transfer */
    USB_LOG_DBG("nsectors: 0x%02x\r\n", g_usbd_msc[busid].nsectors);

    if ((g_usbd_msc[busid].start_sector + g_usbd_msc[busid].nsectors) > g_usbd_msc[busid].scsi_blk_nbr[g_usbd_msc[busid].cbw.bLUN]) {
        SCSI_SetSenseData(busid, SCSI_KCQIR_LBAOUTOFRANGE);
        USB_LOG_ERR("LBA out of range\r\n");
        return false;
    }

    if (g_usbd_msc[busid].cbw.dDataLength != (g_usbd_msc[busid].nsectors * g_usbd_msc[busid].scsi_blk_size[g_usbd_msc[busid].cbw.bLUN])) {
        USB_LOG_ERR("scsi_blk_len does not match with dDataLength\r\n");
        return false;
    }
    g_usbd_msc[busid].stage = MSC_DATA_IN;
#if defined(CONFIG_USBDEV_MSC_THREAD)
    usb_osal_mq_send(g_usbd_msc[busid].usbd_msc_mq, MSC_DATA_IN);
#elif defined(CONFIG_USBDEV_MSC_POLLING)
    chry_ringbuffer_write_byte(&g_usbd_msc[busid].msc_rb, MSC_DATA_IN);
    return true;
#else
    return SCSI_processRead(busid);
#endif
}
```

##### SCSI_CMD_TESTUNITREADY 0x00

- TEST UNIT READY命令(参见表202)提供了一种检查逻辑单元是否就绪的方法。这不是要求自测。如果逻辑单元能够接受适当的介质访问命令而不返回CHECK CONDITION状态，则该命令应返回GOOD状态。如果逻辑单元无法运行或处于需要应用程序客户端操作(例如，START unit命令)使逻辑单元准备就绪的状态，则该命令应以CHECK CONDITION状态终止，并将感测键设置为NOT ready。

```c
static bool SCSI_testUnitReady(uint8_t busid, uint8_t **data, uint32_t *len)
{
    if (g_usbd_msc[busid].cbw.dDataLength != 0U) {
        SCSI_SetSenseData(busid, SCSI_KCQIR_INVALIDCOMMAND);
        return false;
    }
    *data = NULL;
    *len = 0;
    return true;
}
```

##### SCSI_CMD_PREVENTMEDIAREMOVAL 0x1E

- 这个命令告诉UFI设备启用或禁用删除逻辑单元中的介质

| 字节 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|------|---|---|---|---|---|---|---|---|
| **0** | 操作码 (4Eh) | | | | | | | |
| **1** | 逻辑单元号 | | | | | | | |
| **2** | 保留 | | | | | | | |
| **3** | 保留 | | | | | | | |
| **4** | 保留 | | | | | | | Prevent |
| **5** | 保留 | | | | | | | |
| **6** | 保留 | | | | | | | |
| **7** | 保留 | | | | | | | |
| **8** | 保留 | | | | | | | |
| **9** | 保留 | | | | | | | |
| **10** | 保留 | | | | | | | |
| **11** | 保留 | | | | | | | |

-  Prevent: 0x01 防止介质删除 0x00 允许介质删除

```c
static bool SCSI_preventAllowMediaRemoval(uint8_t busid, uint8_t **data, uint32_t *len)
{
    if (g_usbd_msc[busid].cbw.dDataLength != 0U) {
        SCSI_SetSenseData(busid, SCSI_KCQIR_INVALIDCOMMAND);
        return false;
    }
    if (g_usbd_msc[busid].cbw.CB[4] == 0U) {
        //SCSI_MEDIUM_UNLOCKED;
    } else {
        //SCSI_MEDIUM_LOCKED;
    }
    *data = NULL;
    *len = 0;
    return true;
}
```

##### WRITE(10) 0x2a

- WRITE(10)命令请求UFI设备将主机传输的数据写入介质

| 字节 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|------|---|---|---|---|---|---|---|---|
| **0** | 操作码 (2Ah) | | | | | | | |
| **1** | 逻辑单元号 | DPO | FUA | 保留 | RelAdr | | | |
| **2** | (MSB) | 逻辑块地址 | | | | | | |
| **3** | 逻辑块地址 | | | | | | | |
| **4** | 逻辑块地址 | | | | | | | |
| **5** | 逻辑块地址 | (LSB) | | | | | | |
| **6** | 保留 | | | | | | | |
| **7** | 传输长度 (MSB) | | | | | | | |
| **8** | 传输长度 (LSB) | | | | | | | |
| **9** | 保留 | | | | | | | |
| **10** | 保留 | | | | | | | |
| **11** | 保留 | | | | | | | |

- 逻辑块地址:该字段指定写操作开始的逻辑块。

- 传输长度:传输长度字段指定要传输的连续数据逻辑块的数量。传输长度为0表示不传输逻辑块。此情况不应视为错误，也不应写入任何数据。任何其他值表示需要传输的逻辑块的数量

- 主机将要写入的数据发送到Bulk Output端点上的UFI设备。传输的字节数应该是传输长度乘以逻辑块大小。如果WRITE命令成功完成，则UFI设备将感测数据设置为NO sense。否则，设备应将感测数据设置为第5节所列的适当值。如果WRITE命令因为USB位填充错误或CRC错误而被终止，UFI设备应该将感测数据设置为USB to HOST SYSTEM INTERFACE FAILURE。注意:即使发生了写错误，介质也可能被改变了。对于跨越磁盘的多个物理磁道的命令块尤其如此。

```c
/*
    1. 获取传输过来需要写入的LBA和写入的块数,并判断是否超出范围
    2. 判断`dDataLength`是否和`nsectors * scsi_blk_size`相等
    3. 设置`stage`为`MSC_DATA_OUT`,并发送`MSC_DATA_OUT`消息
*/
static bool SCSI_write10(uint8_t busid, uint8_t **data, uint32_t *len)
{
    uint32_t data_len = 0;

    g_usbd_msc[busid].start_sector = GET_BE32(&g_usbd_msc[busid].cbw.CB[2]); /* Logical Block Address of First Block */
    USB_LOG_INFO("lba: 0x%04x\r\n", g_usbd_msc[busid].start_sector);

    g_usbd_msc[busid].nsectors = GET_BE16(&g_usbd_msc[busid].cbw.CB[7]); /* Number of Blocks to transfer */
    USB_LOG_INFO("nsectors: 0x%02x\r\n", g_usbd_msc[busid].nsectors);

    data_len = g_usbd_msc[busid].nsectors * g_usbd_msc[busid].scsi_blk_size[g_usbd_msc[busid].cbw.bLUN];
    if ((g_usbd_msc[busid].start_sector + g_usbd_msc[busid].nsectors) > g_usbd_msc[busid].scsi_blk_nbr[g_usbd_msc[busid].cbw.bLUN]) {
        USB_LOG_ERR("LBA out of range\r\n");
        return false;
    }

    if (g_usbd_msc[busid].cbw.dDataLength != data_len) {
        return false;
    }
    g_usbd_msc[busid].stage = MSC_DATA_OUT;
    data_len = MIN(data_len, CONFIG_USBDEV_MSC_MAX_BUFSIZE);
    usbd_ep_start_read(busid, mass_ep_data[busid][MSD_OUT_EP_IDX].ep_addr, g_usbd_msc[busid].block_buffer, data_len);
    return true;
}
```

#### Command Status Wrapper (CSW)

- 表 5.3 - 命令块状态值

| 值   | 描述                     |
| ---- | ------------------------ |
| 00h  | 命令通过（“good status”）    |
| 01h  | 命令失败                 |
| 02h  | 阶段错误                 |
| 03和04号 | 预留（Obsolete）       |
| 05到FF号 | 预留                  |


```c
/** MSC Bulk-Only Command Status Wrapper (CSW) */
struct CSW {
    uint32_t dSignature;   /* 'USBS' = 0x53425355 */
    uint32_t dTag;         /* Same tag as original command */
    uint32_t dDataResidue; /* Amount not transferred */
    uint8_t bStatus;       /* Status of transfer */
} __PACKED;
```

## HID (Human Interface Device)

### 抓包

### 描述符



```c
static const uint8_t hid_descriptor[] = {
    USB_DEVICE_DESCRIPTOR_INIT(USB_2_0, 0x00, 0x00, 0x00, USBD_VID, USBD_PID, 0x0002, 0x01),
    USB_CONFIG_DESCRIPTOR_INIT(USB_HID_CONFIG_DESC_SIZ, 0x01, 0x01, USB_CONFIG_BUS_POWERED, USBD_MAX_POWER),

    /************** Descriptor of Joystick Mouse interface ****************/
    /* 09 */
    0x09,                          /* bLength: Interface Descriptor size */
    USB_DESCRIPTOR_TYPE_INTERFACE, /* bDescriptorType: Interface descriptor type */
    0x00,                          /* bInterfaceNumber: Number of Interface */
    0x00,                          /* bAlternateSetting: Alternate setting */
    0x01,                          /* bNumEndpoints */
    0x03,                          /* bInterfaceClass: HID */
    0x01,                          /* bInterfaceSubClass : 1=BOOT, 0=no boot */
    0x01,                          /* nInterfaceProtocol : 0=none, 1=keyboard, 2=mouse */
    0,                             /* iInterface: Index of string descriptor */
    /******************** Descriptor of Joystick Mouse HID ********************/
    /* 18 */
    0x09,                    /* bLength: HID Descriptor size */
    HID_DESCRIPTOR_TYPE_HID, /* bDescriptorType: HID */
    0x11,                    /* bcdHID: HID Class Spec release number */
    0x01,
    0x00,                          /* bCountryCode: Hardware target country */
    0x01,                          /* bNumDescriptors: Number of HID class descriptors to follow */
    0x22,                          /* bDescriptorType */
    HID_KEYBOARD_REPORT_DESC_SIZE, /* wItemLength: Total length of Report descriptor */
    0x00,
    /******************** Descriptor of Mouse endpoint ********************/
    /* 27 */
    0x07,                         /* bLength: Endpoint Descriptor size */
    USB_DESCRIPTOR_TYPE_ENDPOINT, /* bDescriptorType: */
    HID_INT_EP,                   /* bEndpointAddress: Endpoint Address (IN) */
    0x03,                         /* bmAttributes: Interrupt endpoint */
    HID_INT_EP_SIZE,              /* wMaxPacketSize: 4 Byte max */
    0x00,
    HID_INT_EP_INTERVAL, /* bInterval: Polling Interval */
    /* 34 */
    ///////////////////////////////////////
    /// string0 descriptor
    ///////////////////////////////////////
    USB_LANGID_INIT(USBD_LANGID_STRING),
    ///////////////////////////////////////
    /// string1 descriptor
    ///////////////////////////////////////
    0x14,                       /* bLength */
    USB_DESCRIPTOR_TYPE_STRING, /* bDescriptorType */
    'C', 0x00,                  /* wcChar0 */
    'h', 0x00,                  /* wcChar1 */
    'e', 0x00,                  /* wcChar2 */
    'r', 0x00,                  /* wcChar3 */
    'r', 0x00,                  /* wcChar4 */
    'y', 0x00,                  /* wcChar5 */
    'U', 0x00,                  /* wcChar6 */
    'S', 0x00,                  /* wcChar7 */
    'B', 0x00,                  /* wcChar8 */
    ///////////////////////////////////////
    /// string2 descriptor
    ///////////////////////////////////////
    0x26,                       /* bLength */
    USB_DESCRIPTOR_TYPE_STRING, /* bDescriptorType */
    'C', 0x00,                  /* wcChar0 */
    'h', 0x00,                  /* wcChar1 */
    'e', 0x00,                  /* wcChar2 */
    'r', 0x00,                  /* wcChar3 */
    'r', 0x00,                  /* wcChar4 */
    'y', 0x00,                  /* wcChar5 */
    'U', 0x00,                  /* wcChar6 */
    'S', 0x00,                  /* wcChar7 */
    'B', 0x00,                  /* wcChar8 */
    ' ', 0x00,                  /* wcChar9 */
    'H', 0x00,                  /* wcChar10 */
    'I', 0x00,                  /* wcChar11 */
    'D', 0x00,                  /* wcChar12 */
    ' ', 0x00,                  /* wcChar13 */
    'D', 0x00,                  /* wcChar14 */
    'E', 0x00,                  /* wcChar15 */
    'M', 0x00,                  /* wcChar16 */
    'O', 0x00,                  /* wcChar17 */
    ///////////////////////////////////////
    /// string3 descriptor
    ///////////////////////////////////////
    0x16,                       /* bLength */
    USB_DESCRIPTOR_TYPE_STRING, /* bDescriptorType */
    '2', 0x00,                  /* wcChar0 */
    '0', 0x00,                  /* wcChar1 */
    '2', 0x00,                  /* wcChar2 */
    '2', 0x00,                  /* wcChar3 */
    '1', 0x00,                  /* wcChar4 */
    '2', 0x00,                  /* wcChar5 */
    '3', 0x00,                  /* wcChar6 */
    '4', 0x00,                  /* wcChar7 */
    '5', 0x00,                  /* wcChar8 */
    '6', 0x00,                  /* wcChar9 */
#ifdef CONFIG_USB_HS
    ///////////////////////////////////////
    /// device qualifier descriptor
    ///////////////////////////////////////
    0x0a,
    USB_DESCRIPTOR_TYPE_DEVICE_QUALIFIER,
    0x00,
    0x02,
    0x00,
    0x00,
    0x00,
    0x40,
    0x01,
    0x00,
#endif
    0x00
};
```
