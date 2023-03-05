# 作业1：指令集体系结构与折衷

**苏星熠 ZY2206148**

## 1.  比较五种不同风格的指令集代码序列的内存效率

- a. 将下边的高级语言片段翻译成前述 5 种结构适用的代码序列。一定要确保将 A、B、D 的值存回内存，但是不能修改内存中任何其它的数值。

  ```
  A = B + C;
  B = A + C;
  D = A - B;
  ```

  + 零地址指令

    ```
    PUSH B;
    PUSH C;
    ADD;
    POP A;
    PUSH A;
    PUSH B;
    ADD;
    POP B;
    PUSH A;
    PUSH B;
    SUB;
    POP D;
    ```

    

  + 单地址指令

    ```
    LOAD B;
    ADD C;
    STORE A;
    ADD C;
    STORE B;
    LOAD A;
    SUB B;
    STORE D;
    ```

    

  + 双地址指令

    ```
    ADD B C;
    STORE B A;	//虽然题目没有给出存储转移操作，但这种操作是必要的，使用此条指令将内存B中当前值存储到内存A中
    ADD B C;	//A、B当前存储值相等，如此操作可以顺势存储期望的值到B中
    STORE A D;
    SUB D B;
    ```

    

  + 三地址指令——内存

    ```
    ADD A B C;
    ADD B A C;
    SUB D A B;
    ```

    

  + 三地址指令——寄存器

    ```
    LD R1 B;
    LD R2 C;
    ADD R1 R1 R2;
    ST R1 A;
    ADD R2 R1 R2;
    ST R2 B;
    SUB R1 R1 R2;
    ST R1 D;
    ```

- 请计算这 5 种结构对应的指令序列在执行时的取指令字节数和内存数据访问（读和写）字节数。

  C代表指令长度；R代表读取字节数；W代表写入字节数。

  - 零地址指令

    每个PUSH或POP对应一次内存读取与写入；

    每个ADD或SUB对应两次内存读取与一次内存写入。
    $$
    C_0 = 12 \times L_{op} + 8 \times L_{mem} = 28 bytes \newline
    R_0 = 15 \times L_{data} = 60 bytes \newline
    W_0 = 12 \times L_{data} = 48 bytes
    $$

  - 单地址指令

    每个LOAD对应一次内存读取；

    每个STORE对应一次内存写入；

    每个ADD或SUB对应一次内存读取；
    $$
    C_1 = 8 \times L_{op} + 8 \times L_{mem} = 24 bytes \newline
    R_1 = 5 \times L_{data} = 20 bytes \newline
    W_1 = 3 \times L_{data} = 12 bytes
    $$

  - 双地址指令

    每个ADD或SUB对应两次内存读取和一次内存写入；

    每个STORE对应一次内存读取与写入；
    $$
    C_2 = 5 \times L_{op} + 10 \times L_{mem} = 25 bytes \newline
    R_2 = 8 \times L_{data} = 32 bytes \newline
    W_2 = 5 \times L_{data} = 20 bytes
    $$

  - 三地址指令——内存

    每个ADD或SUB对应两次内存读取与一次内存写入；
    $$
    C_{31} = 3 \times L_{op} + 9 \times L_{mem} = 21 bytes \newline
    R_{31} = 6 \times L_{data} = 24 bytes \newline
    W_{31} = 3 \times L_{data} = 12 bytes
    $$

  - 三地址指令——寄存器

    每个LD对应一次内存读取；

    每个ST对应一次内存写入；
    $$
    C_{32} = 8 \times L_{op} + 14 \times L_{reg} + 5 \times L_{mem} = 32 bytes \newline
    R_{32} = 2 * L_{data} = 8 bytes \newline
    W_{32} = 3 * L_{data} = 12 bytes
    $$

- 从代码尺寸的角度哪一种结构最高效? 

  无论是代码长度还是存储代码空间大小，都是使用内存地址的三地址指令最好。

- 从内存总带宽的需求（代码+数据）角度哪一种结构最高效? 

  整体而言，使用寄存器的三地址指令最高效。

## 2. 固定长度和可变长度 ISA
