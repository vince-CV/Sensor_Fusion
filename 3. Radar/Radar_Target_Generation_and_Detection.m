clear all;
clc;

%% Radar Specifications
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Frequency of operation = 77GHz
% Max Range = 200m
% Range Resolution = 1 m
% Max Velocity = 100 m/s
%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% User Defined Range and Velocity of target
% *%TODO* :
% define the target's initial position and velocity. Note : Velocity remains contant

c = 3*10^8;                    % Light speed
f = 77.0e9;

range_resolution = 1;         
range_max = 200;           
velocity_max = 100;          

targetPosition = 80;
targetVelocity = 50;


%% FMCW Waveform Generation
%Design the FMCW waveform by giving the specs of each of its parameters.
% Calculate the Bandwidth (B), Chirp Time (Tchirp) and Slope (slope) of the FMCW chirp

Bsweep = c / (2 * range_resolution);         % bandwidth
Ts = 5.5 * (range_max * 2 / c);      % chirp time
k = Bsweep / Ts;                    % slope
fprintf('slope = %d\n', k)

                                           
%The number of chirps in one sequence. Ideal to 2^ value for the ease of running the FFT for Doppler Estimation.
Nd = 128;                           % #of doppler cells OR #of sent periods % number of chirps

%The number of samples on each chirp.
Nr = 1024;                          % for length of time OR # of range cells

% Timestamp for running the displacement scenario for every sample on each
% chirp
t = linspace(0, Nd*Ts, Nr*Nd);    % total time for samples


%Creating the vectors for Tx, Rx and Mix based on the total samples input.
Tx = zeros(1,length(t));            % transmitted signal
Rx = zeros(1,length(t));            % received signal
Mix = zeros(1,length(t));           % beat signal

%Similar vectors for range_covered and time delay.
r_t = zeros(1,length(t));
td = zeros(1,length(t));


%% Signal generation and Moving Target simulation

for i=1:length(t)        
    %For each time stamp update the Range of the Target for constant velocity.
    r_t(i) = targetPosition + t(i) * targetVelocity;
    td(i) = 2 * r_t(i) / c;   
   
    %For each time sample we need update the transmitted and received signal.
    Tx(i) = cos(2 * pi * (f * t(i) + 0.5 * k * t(i) * t(i) ));
    Rx(i) = cos(2 * pi * (f * (t(i) - td(i)) + 0.5 * k * (t(i) - td(i))*(t(i) - td(i)) ));
   
    %Mixing the Transmit and Receive generate the beat signal
    Mix(i) = Tx(i) .* Rx(i);        % done by element wise matrix multiplication of Transmit and
end

figure();
grid on;
subplot(311);plot(Tx(1:600));title('transmitted signal');
xlabel('time');
ylabel('amplitude');
subplot(312);plot(Rx(1:600));title('received signal');
xlabel('time');
ylabel('amplitude');
subplot(313);plot(Mix(1:600));title('beat signal');
xlabel('time');
ylabel('amplitude');



%% RANGE MEASUREMENT


%reshape the vector into Nr*Nd array. Nr and Nd here would also define the size of
%Range and Doppler FFT respectively.
Mix_1 = reshape(Mix, Nr, Nd);

%run the FFT on the beat signal along the range bins dimension (Nr) and
%normalize.
fft1 = fft(Mix_1, Nr)./ Nr;

% Take the absolute value of FFT output
fft1 = abs(fft1);

% Output of FFT is double sided signal, but we are interested in only one side of the spectrum.
% Hence we throw out half of the samples.
half_fft1 = fft1(1 : Nr/2);

%plotting the range
figure ();
plot(half_fft1); 
axis ([0 300 0 0.3]); 
grid on;
title( 'Range from FFT');
xlabel('range');
ylabel('amplitude');



%% RANGE DOPPLER RESPONSE
% The 2D FFT implementation is already provided here. This will run a 2DFFT
% on the mixed signal (beat signal) output and generate a range doppler
% map.You will implement CFAR on the generated RDM

% Range Doppler Map Generation.
% The output of the 2D FFT is an image that has reponse in the range and
% doppler FFT bins. So, it is important to convert the axis from bin sizes
% to range and doppler based on their Max values.
Mix=reshape(Mix,[Nr,Nd]);

% 2D FFT using the FFT size for both dimensions.
sig_fft2 = fft2(Mix,Nr,Nd);

% Taking just one side of signal from Range dimension.
sig_fft2 = sig_fft2(1:Nr/2,1:Nd);
sig_fft2 = fftshift (sig_fft2);
RDM = abs(sig_fft2);
RDM = 10*log10(RDM) ;

%use the surf function to plot the output of 2DFFT and to show axis in both
%dimensions
doppler_axis = linspace(-100,100,Nd);
range_axis = linspace(-200,200,Nr/2)*((Nr/2)/400);
figure,surf(doppler_axis,range_axis,RDM);
title( 'FMCW Radar 2D-FFT');
xlabel('speed');
ylabel('range');
zlabel('amplitude');

%% CFAR implementation

%Slide Window through the complete Range Doppler Map

% *%TODO* :
%Select the number of Training Cells in both the dimensions.
T_x = 10;
T_y = 5;

% *%TODO* :
%Select the number of Guard Cells in both dimensions around the Cell under 
%test (CUT) for accurate estimation
G_x = 4;
G_y = 2;

% *%TODO* :
% offset the threshold by SNR value in dB
offset = 0.6 ;

% *%TODO* :
%Create a vector to store noise_level for each iteration on training cells
noise_level = zeros(1,1);

% *%TODO* :
%design a loop such that it slides the CUT across range doppler map by
%giving margins at the edges for Training and Guard Cells.
%For every iteration sum the signal level within all the training
%cells. To sum convert the value from logarithmic to linear using db2pow
%function. Average the summed values for all of the training
%cells used. After averaging convert it back to logarithimic using pow2db.
%Further add the offset to it to determine the threshold. Next, compare the
%signal under CUT with this threshold. If the CUT level > threshold assign
%it a value of 1, else equate it to 0.


   % Use RDM[x,y] as the matrix from the output of 2D FFT for implementing
   % CFAR

% normalization
RDM = RDM / max(RDM(:));


% 2D-CFAR
for i = T_x + G_x + 1: Nr/2 - T_x - G_x 
     for j = T_y + G_y + 1 : Nd - T_y - G_y
         
         sum = 0;
         cell = 0;
         
         for ii = (i - T_x - G_x) : (i + T_x + G_x)
             for jj = (j - T_y - G_y) : (j + T_y + G_y)
                 if ((abs(i - ii) > G_x) || (abs(j - jj) > G_y))
                     sum = sum + db2pow(RDM(ii, jj));
                     cell = cell + 1;
                 end
             end
         end
         
         threshold = pow2db(sum/cell) +offset;
         
         if RDM(i, j) > threshold
             RDM(i, j) = 1;
         else
             RDM(i, j) = 0;
         end
		 
		 
    end
end


% *%TODO* :
% The process above will generate a thresholded block, which is smaller 
%than the Range Doppler Map as the CUT cannot be located at the edges of
%matrix. Hence,few cells will not be thresholded. To keep the map size same
% set those values to 0. 

for i = 1: Nr/2 
     for j = 1 : Nd
	 
         if ((RDM(i, j) ~= 0) && (RDM(i, j) ~= 1))
             RDM(i, j) = 0;
             
         end
     end
end

% *%TODO* :
%display the CFAR output using the Surf function like we did for Range
%Doppler Response output.
%figure,surf(doppler_axis,range_axis,'replace this with output');
%colorbar;

figure,surf(doppler_axis,range_axis,RDM);title( 'FMCW Radar 2D-CFAR');
xlabel('speed');
ylabel('range');
zlabel('binary amplitude');
colorbar;



 

