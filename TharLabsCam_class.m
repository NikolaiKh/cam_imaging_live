classdef TharLabsCam_class
    properties
        serialNumbers
        tlCameraSDK
        tlCamera
    end

    methods
        function obj = TharLabsCam_class()
            % Load TLCamera DotNet assembly. The assembly .dll is assumed to be in the
            % same folder as the scripts.
            dll_dir = [pwd '\Managed_64_lib'];
            NET.addAssembly([dll_dir, '\Thorlabs.TSI.TLCamera.dll']);
            disp('Dot NET assembly loaded.');

            obj.tlCameraSDK = Thorlabs.TSI.TLCamera.TLCameraSDK.OpenTLCameraSDK;

            % Get serial numbers of connected TLCameras.
            obj.serialNumbers = obj.tlCameraSDK.DiscoverAvailableCameras;
            disp([num2str(obj.serialNumbers.Count), ' camera was discovered.']);
            obj.tlCamera = obj.tlCameraSDK.OpenCamera(obj.serialNumbers.Item(0), false);
            disp('Camera is loaded');
        end

        function [imageData, imageHeight, imageWidth] = takesnap(obj, exptime)
            % Set exposure time and gain of the camera.
            obj.tlCamera.ExposureTime_us = exptime;

            % Check if the camera supports setting "Gain"
            gainRange = obj.tlCamera.GainRange;
            if (gainRange.Maximum > 0)
                obj.tlCamera.Gain = 0;
            end

            % Set the FIFO frame buffer size. Default size is 1.
            obj.tlCamera.MaximumNumberOfFramesToQueue = 5;

            obj.tlCamera.OperationMode = Thorlabs.TSI.TLCameraInterfaces.OperationMode.SoftwareTriggered;
            obj.tlCamera.FramesPerTrigger_zeroForUnlimited = 0;
            obj.tlCamera.Arm;
            obj.tlCamera.IssueSoftwareTrigger;

            numberOfFramesToAcquire = 1;
            frameCount = 0;
            while frameCount < numberOfFramesToAcquire
                % Check if image buffer has been filled
                if (obj.tlCamera.NumberOfQueuedFrames > 0)

                    % If data processing in Matlab falls behind camera image
                    % acquisition, the FIFO image frame buffer could overflow,
                    % which would result in missed frames.
                    if (obj.tlCamera.NumberOfQueuedFrames > 1)
                        disp(['Data processing falling behind acquisition. ' num2str(obj.tlCamera.NumberOfQueuedFrames) ' remains']);
                    end

                    % Get the pending image frame.
                    imageFrame = obj.tlCamera.GetPendingFrameOrNull;
                    if ~isempty(imageFrame)
                        frameCount = frameCount + 1;

                        % Get the image data as 1D uint16 array
                        imageData = uint16(imageFrame.ImageData.ImageData_monoOrBGR);

                        disp(['Image frame number: ' num2str(imageFrame.FrameNumber)]);

                        % TODO: custom image processing code goes here
                        imageHeight = imageFrame.ImageData.Height_pixels;
                        imageWidth = imageFrame.ImageData.Width_pixels;
                        % imageData2D = reshape(imageData, [imageWidth, imageHeight]);
                    end
                    % Release the image frame
                    delete(imageFrame);
                end
            end
            % Stop continuous image acquisition
            disp('Stopping continuous image acquisition.');
            obj.tlCamera.Disarm;
        end

        function cam_delete(obj)
            % Release the TLCamera
            disp('Releasing the camera');
            obj.tlCamera.Dispose;
            delete(obj.tlCamera);

            % Release the serial numbers
            delete(obj.serialNumbers);

            % Release the TLCameraSDK.
            obj.tlCameraSDK.Dispose;
            delete(obj.tlCameraSDK);
        end
    end
end