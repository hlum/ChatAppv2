import SwiftUI
import _PhotosUI_SwiftUI

final class OnboardingViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var age: Double = 50
    @Published var gender: String = "男性"
    @Published var preferences: [String] = []
    @Published var imageSelection:PhotosPickerItem? = nil
    @Published var profileImage:UIImage? = nil
    @Published var wantToTalk :WantToTalk = .Three
    
//    var tokens:GoogleSignInResultModel? = nil
    
    
    @Published var alertTitle: String = ""
    @Published var showAlert: Bool = false
    
    @Published var showFields:Bool = false
    @Published var isLoading:Bool = false
    @Published var progress:Double = 0.0
    
    
    @MainActor
    func showAlertTitle(title: String) {
        self.alertTitle = title
        showAlert.toggle()
    }
}

//SignIn with google
extension OnboardingViewModel{
    
    
    func signInWithGoogle() async throws {
        await MainActor.run {
            isLoading = true
            progress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
                progress = 1.0
            }
        }
        
        do {
            let helper = SignInGoogleHelper()
            await updateProgress(0.2)
            
            
            let tokens = try await helper.signIn()
            await updateProgress(0.4)
            
#warning("Change this to make sure the email is from the right school")
//            guard let email = tokens.email,
//                email.hasSuffix("@jec.ac.jp") else{
//                await self.showAlertTitle(title: "学校のメール以外はログイン出来ません。")
//                return
//            }

            
            await updateProgress(0.6)
            let authDataResult = try await AuthenticationManager.shared.signInWithGoogle(tokens:tokens)

            // Check if the user is new
            let isNewUser = !(try await UserManager.shared.checkIfUserExistInDatabase(userId: authDataResult.uid))
            await updateProgress(0.8)
            
            await MainActor.run {
                if isNewUser {
                    self.showFields = true
                } else {
                    self.showFields = false
                }
            }
            
            await updateProgress(1.0)
        } catch let error{
            await MainActor.run {
                // Handle error, maybe show an alert
                self.alertTitle = "サインインに失敗しました\(error.localizedDescription)"
                self.showAlert = true
            }
            throw error
        }
    }
    
    func saveUserInputs() async {
        await MainActor.run {
            isLoading = true
            progress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
                progress = 1.0
            }
        }
        
        guard let authDataResult = try? AuthenticationManager.shared.getAuthenticatedUser() else {
            print("OnBoardingView/saveUserInput:Can't get authdatResult")
            return
        }
        
        guard let profileImage = self.profileImage else {
            print("BoardingView/signInWithGoogle:NO photo")
            return
        }
        
        do {
            // Save image
            await updateProgress(0.2)
            let photoURL = try await UserManager.shared.saveImageInStorage(image: profileImage, userId: authDataResult.uid)
            await updateProgress(0.6)
//            let photoURL = try await UserManager.shared.saveImageInStorage(image: profileImage, userId: authDataResult.uid){ percentCompleted in
//                await updateProgress(0.6)
//            }

            let newUser = DBUser(
                authDataResult: authDataResult,
                photoUrl: photoURL,
                preferences: preferences,
                name: name,
                age: age,
                wantToTalk: wantToTalk
            )
            
            // Save user data
            await updateProgress(0.8)
            await UserManager.shared.storeNewUser(user: newUser)
            await updateProgress(1.0)
        } catch {
            print("Error saving user data: \(error)")
            // Handle the error appropriately
        }
    }
    
    @MainActor
    private func updateProgress(_ newProgress: Double) {
        progress = newProgress
    }
}
//load the Image func
extension OnboardingViewModel {
    func loadTransferableImage() {
        guard let imageSelection else { return }
        
        Task {
            do {
                let transferableImage = try await imageSelection.loadTransferable(type: TransferableImage.self)
                await MainActor.run {
                    self.profileImage = transferableImage?.image

                }
            } catch {
                print("Failed to load transferable image: \(error)")
            }
        }
    }
}

struct OnboardingView: View {
    @State private var dragOffset: CGSize = .zero
    @State var onboardingState: Int = 0
    let transition: AnyTransition = .asymmetric(
        insertion: .move(edge: .trailing),
        removal: .move(edge: .leading))
    @StateObject var vm = OnboardingViewModel()
    @Binding var isUserCurrentlyLoggedOut : Bool
    
    let interests = [
        // 元のリスト
        "スポーツ", "音楽", "映画", "読書", "料理", "旅行", "ゲーム", "アート",
        "写真撮影", "フィットネス", "ヨガ", "ダンス", "ハイキング", "キャンプ", "ガーデニング",
        "釣り", "ボランティア活動", "登山", "自転車", "ボードゲーム", "アニメ", "マンガ",
        "瞑想", "書道", "手芸", "ドローン", "カフェ巡り", "DIY", "サイクリング", "プログラミング",
        "言語学習", "ペットの世話", "謎解き",
        // 前回追加したもの
        "バードウォッチング", "ワイン試飲", "陶芸", "スキューバダイビング", "天体観測",
        "ジグソーパズル", "コスプレ", "ビデオ編集", "盆栽", "クラシック音楽鑑賞",
        // 新しく追加する趣味
        "茶道", "華道", "囲碁", "将棋", "カリグラフィー", "折り紙", "切り絵", "漫才", "落語",
        "篆刻", "剣道", "弓道", "相撲観戦", "歌舞伎鑑賞", "能・狂言鑑賞", "和太鼓",
        "三味線", "琴", "尺八", "日本舞踊", "着物の着付け", "香道", "パン作り", "そば打ち",
        "フラワーアレンジメント", "ミニチュア製作", "ドールハウス作り", "鉄道模型",
        "切手収集", "コイン収集", "アンティーク収集", "ワインセラー管理", "ウイスキー蒐集",
        "ハーブ栽培", "盆景", "苔玉作り", "テラリウム作り", "昆虫採集", "化石発掘",
        "星座観察", "気象観測", "グランピング", "サバイバルキャンプ", "ロッククライミング",
        "パラグライダー", "スカイダイビング", "バンジージャンプ", "カヌー", "ラフティング"
    ]
    @Namespace var nameSpace
    var body: some View {
            ZStack {
                Color.customBlack.ignoresSafeArea()
                ZStack {
                    switch onboardingState {
                    case 0:
                        welcomeSection
                            .transition(transition)
                    case 1:
                        addNameSection
                            .transition(transition)
                    case 2:
                        addAgeSection
                            .transition(transition)
                    case 3:
                        addGenderSection
                            .transition(transition)
                    case 4:
                        wantToTalkSection
                            .transition(transition)
                    case 5:
                        userInterestsSection
                            .transition(transition)
                    default:
                        RoundedRectangle(cornerRadius: 25.0)
                            .foregroundColor(.green)
                    }
                }
                VStack {
                    Spacer()
                    
                    signUpButton
                }
                .padding(30)
                
                   if vm.isLoading {
                       Color.black.opacity(0.5).ignoresSafeArea()
                       VStack {
                           ProgressView()
                               .progressViewStyle(CircularProgressViewStyle(tint: .white))
                               .scaleEffect(2)
                           
                           ProgressView(value: vm.progress)
                               .frame(width: 200)
                               .tint(.white)
                               .padding()
                           
                           Text("\(Int(vm.progress * 100))%")
                               .foregroundColor(.white)
                               .font(.headline)
                       }
                   }
            }
        
            .alert(isPresented: $vm.showAlert) {
                Alert(title: Text(vm.alertTitle))
                
            }

        }
 }

extension OnboardingView {
    private var signUpButton: some View {
        Text(onboardingState == 0 ? "サインアップ" :
             onboardingState == 4 ? "完了" :
             "次へ")
            .font(.headline)
            .foregroundColor(Color(.customWhite))
            .frame(height: 55)
            .frame(maxWidth: .infinity)
            .background(Color.customOrange)
            .cornerRadius(10)
            .onTapGesture {
                withAnimation(.easeInOut) {
                    handleNextButtonPressed()
                }
            }
            .shadow(color: Color.customOrange, radius: 10)
    }
    
    private var welcomeSection: some View {
        VStack(spacing: 40) {
            Spacer()
            Text("友達を探しましょう。。")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(Color.customWhite)
                .overlay(
                    Capsule(style: .continuous)
                        .frame(height: 3)
                        .offset(y: 5)
                        .foregroundColor(.white),
                    alignment: .bottom
                )
            Text("校内の同じ趣味を持っている人と話し合いましょう。。")
                .fontWeight(.medium)
                .foregroundColor(Color.customWhite)
            Spacer()
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding(30)
    }
    
    private var addNameSection: some View {
        VStack(spacing: 20) {
            ImagePickerView
                .onAppear{
                    Task{
                        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                    }
                }
                .onChange(of: vm.imageSelection) {
                    vm.loadTransferableImage()
                }
            Text("あなたの名前は？")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(Color.customWhite)
            
            TextField("ここに名前を入力...", text: $vm.name)
                .font(.headline)
                .frame(height: 55)
                .padding(.horizontal)
                .background(.white)
                .cornerRadius(10)
            Spacer()
            Spacer()
        }.padding(30)
    }
    
    private var ImagePickerView : some View{
        VStack{
            PhotosPicker(selection: $vm.imageSelection,matching: .images) {
                VStack{
                    if let image = vm.profileImage{
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(Circle())
                            .frame(width: 128, height: 128)
                        
                    }else{
                        VStack{
                            Image(.profilePic)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipShape(.circle)
                                .frame(width: 128,height: 128)
                            Text("プロフィール画像を選択してください")
                                .font(.headline)
                                .foregroundStyle(Color(.red))
                        }
                    }
                    
                }
                .padding(.vertical)
            }
            if vm.imageSelection != nil{
                Button("Remove Image"){
                    vm.imageSelection = nil
                    vm.profileImage = nil
                }
            }
        }
    }
    
    private var addAgeSection: some View {
        VStack(spacing: 40) {
            Spacer()
            Text("あなたの年齢は？")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("\(String(format: "%.0f", vm.age))歳")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Slider(value: $vm.age, in: 18...100, step: 1)
                .accentColor(.white)
            
            Spacer()
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding(30)
    }
    
    private var addGenderSection: some View {
        VStack(spacing: 40) {
            Spacer()
            Text("あなたの性別は？")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Picker("性別を選択", selection: $vm.gender) {
                Text("男性").tag("男性")
                Text("女性").tag("女性")
                Text("その他").tag("その他")
            }
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .padding()
            .background(Color.customWhite)
            .cornerRadius(10)
            .pickerStyle(.menu)
            .tint(Color.customBlack)
            
            Spacer()
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding(30)
    }
    
    private var wantToTalkSection:some View{
        VStack(alignment: .center){
            Text("今の気分は？")
                .foregroundStyle(Color.white)
                .font(.largeTitle)
            HStack{
                ForEach(WantToTalk.allCases, id: \.self) { level in
                    Button {
                        withAnimation(.bouncy) {
                            vm.wantToTalk = level
                        }
                    } label: {
                        ZStack{
                            if vm.wantToTalk == level{
                                    RoundedRectangle(cornerRadius: 10)
                                    .fill(.customOrange)
                                        .frame(width:vm.wantToTalk == level ? 80: 50,height: 55)
                                        .cornerRadius(30)
                                        .padding(.vertical,4)
                                        .matchedGeometryEffect(id: "backGroundRectangleId", in: nameSpace)
                            }
                            Text(level.rawValue)
                                .font(.system(size: vm.wantToTalk == level ? 50 : 30))
                                .cornerRadius(90)
                        }
                        
                    }
                    
                }
            }
            
            .padding(.horizontal)
            .background(.white)
            .cornerRadius(80)
        }
    }
    
    private var userInterestsSection: some View {
        VStack(spacing: 20) {
            Text("興味のある分野を選択してください")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    ForEach(interests, id: \.self) { interest in
                        InterestButton(title: interest, isSelected: vm.preferences.contains(interest)) {
                            if vm.preferences.contains(interest) {
                                guard let index = vm.preferences.firstIndex(of: interest)else {return}
                                vm.preferences.remove(at: index)
                            } else {
                                vm.preferences.append(interest)
                            }
                        }
                    }
                }
            }
        }
        .padding(30)
        .padding(.bottom,55)
    }
}

struct InterestButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(isSelected ? .white : .customOrange)
                .padding()
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.customOrange : Color.white)
                .cornerRadius(10)
        }
    }
}

extension OnboardingView {
    
    private func handleNextButtonPressed() {
        switch onboardingState {
        case 0:
            Task {
                do {
                    try await vm.signInWithGoogle()
                    if vm.showFields {
                        withAnimation(.spring()) {
                            onboardingState += 1
                        }
                    }else{
                        self.isUserCurrentlyLoggedOut = !AuthenticationManager.shared.checkIfUserIsAuthenticated()
                    }
                } catch {
                    print("Error signing in with Google: \(error)")
                }
            }
        case 1:
            guard vm.name.count > 2 else{
                vm.showAlertTitle(title: "名前は３文字以上入力してください！！")
                return
            }
            guard vm.imageSelection != nil else{
                vm.showAlertTitle(title: "プロフィール写真を選択してください！！")
                return
            }
            withAnimation(.spring()) {
                onboardingState += 1
            }
            
        case 4:
            withAnimation {
                onboardingState += 1
            }
        case 5:
            guard !vm.preferences.isEmpty else {
                vm.showAlertTitle(title: "少なくとも1つの興味を選択してください！")
                return
            }
            
            Task {
                await vm.saveUserInputs()
                await MainActor.run {
                    self.isUserCurrentlyLoggedOut = false
                }
            }
        default:
            withAnimation(.spring()) {
                onboardingState += 1
            }
        }
    }
}

#Preview {
    OnboardingView(isUserCurrentlyLoggedOut: .constant(true))
}
